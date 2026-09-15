import AppKit
import Carbon.HIToolbox
import SwiftUI
import Combine

/// Orchestrates the wheel lifecycle:
/// hotkey down → show → track mouse → hotkey up → fire action.
final class WheelController {

    // ── State ─────────────────────────────────────────────────────────────────
    private let state      = WheelState()
    private let hotkeyMgr  = HotkeyManager()
    private var wheel: Wheel!

    // Per-segment mutable sticky indices (not persisted yet — v1)
    private var stickyIndices: [Int: Int] = [:]
    // Last fired action for tap-to-repeat
    private var lastFired: (segmentIdx: Int, actionIdx: Int)?

    // ── Windows (created once, reused) ────────────────────────────────────────
    private let panel    = WheelPanel()
    private let backdrop = BackdropWindow()

    // ── Event monitors (non-nil only while wheel is open) ────────────────────
    private var mouseMonitor:  Any?
    private var scrollMonitor: Any?
    private var keyMonitor:    Any?
    private var keyUpMonitor:  Any?

    // Tracks currently held arrow keys for diagonal detection
    private var pressedArrows: Set<UInt16> = []

    // ── Haptics ───────────────────────────────────────────────────────────────
    private var cancellables: Set<AnyCancellable> = []

    // ── Timing ────────────────────────────────────────────────────────────────
    private var keyDownDate: Date?
    private let tapThreshold: TimeInterval = 0.18

    // ── Screen where cursor was on keydown ────────────────────────────────────
    private var activeScreen: NSScreen?

    // ─────────────────────────────────────────────────────────────────────────
    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Public API
    // ─────────────────────────────────────────────────────────────────────────

    var currentWheel: Wheel { wheel }

    /// Apply an updated wheel (called after settings save).
    func apply(_ updated: Wheel) {
        wheel       = updated
        state.wheel = updated
        stickyIndices = [:]
        for (i, seg) in updated.segments.enumerated() {
            stickyIndices[i] = seg.stickyIndex
        }
        state.actionIndices = stickyIndices
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Setup
    // ─────────────────────────────────────────────────────────────────────────

    func setup() {
        wheel = ConfigLoader.load()
        state.wheel = wheel

        // Initialise sticky indices from config
        for (i, seg) in wheel.segments.enumerated() {
            stickyIndices[i] = seg.stickyIndex
        }
        state.actionIndices = stickyIndices

        // Install SwiftUI wheel into the panel (once, at launch)
        let hostingView = NSHostingView(rootView: WheelView(state: state))
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        // Haptic feedback on every segment change (including center)
        state.$highlightedIndex
            .dropFirst()
            .removeDuplicates()
            .sink { _ in
                NSHapticFeedbackManager.defaultPerformer.perform(
                    .generic, performanceTime: .default
                )
            }
            .store(in: &cancellables)

        // Register hotkey — F13 by default
        hotkeyMgr.onKeyDown = { [weak self] in self?.handleKeyDown() }
        hotkeyMgr.onKeyUp   = { [weak self] in self?.handleKeyUp()   }

        let keyCode   = KeyMapper.keyCode(for: wheel.hotkey.key) ?? 49   // fallback: Space
        let modifiers = KeyMapper.modifiers(from: wheel.hotkey.modifiers)
        hotkeyMgr.register(keyCode: keyCode, modifiers: modifiers)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Key events
    // ─────────────────────────────────────────────────────────────────────────

    private func handleKeyDown() {
        keyDownDate = Date()
        let cursor = NSEvent.mouseLocation

        // Determine screen
        activeScreen = NSScreen.screens.first { $0.frame.contains(cursor) } ?? NSScreen.main

        guard let screen = activeScreen else { return }

        // Cover that screen
        panel.setFrame(screen.frame,    display: false)
        backdrop.setFrame(screen.frame, display: false)

        // Wheel origin in SwiftUI view coordinates (y-down, origin top-left of screen)
        state.wheelOrigin = toViewCoord(cursor, screen: screen)
        state.highlightedIndex = nil
        state.dynamicActions = [:]   // clear stale results from last open

        // Populate dynamic segments before showing — blocks briefly for fast commands
        populateDynamicSegments()

        // Show backdrop first (lower z-order), then panel.
        // makeKeyAndOrderFront lets panel receive keyboard events without
        // activating the app (nonactivatingPanel keeps frontmost app unchanged).
        backdrop.orderFront(nil)
        panel.makeKeyAndOrderFront(nil)

        startTracking()
    }

    private func handleKeyUp() {
        let elapsed = keyDownDate.map { Date().timeIntervalSince($0) } ?? 1
        keyDownDate = nil

        stopTracking()
        panel.orderOut(nil)
        backdrop.orderOut(nil)

        if elapsed < tapThreshold {
            // Tap: repeat last action
            if let last = lastFired {
                let actions = effectiveActions(for: last.segmentIdx)
                guard !actions.isEmpty else { return }
                let action = actions[min(last.actionIdx, actions.count - 1)]
                ActionExecutor.execute(action)
            }
            return
        }

        guard let idx = state.highlightedIndex else { return }  // dead zone = cancel

        let actions = effectiveActions(for: idx)
        guard !actions.isEmpty else { return }
        let actionIdx = min(stickyIndices[idx] ?? 0, actions.count - 1)
        let action = actions[actionIdx]

        // Update sticky
        stickyIndices[idx] = actionIdx
        lastFired = (idx, actionIdx)

        ActionExecutor.execute(action)

        // Reset highlight
        state.highlightedIndex = nil
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Event monitoring
    // ─────────────────────────────────────────────────────────────────────────

    private func startTracking() {
        stopTracking()  // idempotent; guards against duplicate hotkey press events
        // Mouse movement
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged]
        ) { [weak self] _ in
            self?.updateFromCursor()
        }

        // Scroll wheel — cycle actions within highlighted level-2 segment
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScroll(delta: event.scrollingDeltaY)
        }

        // Key-down: step through center on each press.
        // Held arrow keys let diagonals be selected; each press steps one position.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            switch event.keyCode {
            case 123, 124, 125, 126:              // arrow keys
                self.pressedArrows.insert(event.keyCode)
                self.stepTowardPressedDirection()
                return nil
            case 53:                              // Esc → cancel and close immediately
                self.cancelAndClose()
                return nil
            case 36, 76:                          // Return / numpad Enter
                if self.state.highlightedIndex == nil {
                    self.cancelAndClose()
                } else {
                    self.fireCurrentSegment()
                }
                return nil
            default:
                if let ch = event.characters, let n = Int(ch), (1...8).contains(n) {
                    self.state.highlightedIndex = n - 1
                    return nil
                }
                return event
            }
        }

        // Key-up: remove from set, no selection change (selection sticks on key release).
        keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard let self = self else { return event }
            if [123, 124, 125, 126].contains(event.keyCode) {
                self.pressedArrows.remove(event.keyCode)
                return nil
            }
            return event
        }

        // Seed immediately so the first frame is correct
        updateFromCursor()
    }

    private func stopTracking() {
        [mouseMonitor, scrollMonitor, keyMonitor, keyUpMonitor].compactMap { $0 }.forEach {
            NSEvent.removeMonitor($0)
        }
        mouseMonitor  = nil
        scrollMonitor = nil
        keyMonitor    = nil
        keyUpMonitor  = nil
        pressedArrows.removeAll()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Cursor tracking
    // ─────────────────────────────────────────────────────────────────────────

    private func updateFromCursor() {
        guard let screen = activeScreen else { return }
        let viewPos = toViewCoord(NSEvent.mouseLocation, screen: screen)
        let origin  = state.wheelOrigin

        let dx = viewPos.x - origin.x
        let dy = viewPos.y - origin.y   // both y-down; dy+ = down on screen
        let dist = sqrt(dx * dx + dy * dy)

        guard dist > 40 else {
            state.highlightedIndex = nil
            return
        }

        // atan2(dx, -dy): angle from "up" direction, clockwise in y-down coords.
        // 0° = top, 90° = right, 180° = bottom, 270° = left.
        var deg = atan2(dx, -dy) * 180 / .pi
        if deg < 0 { deg += 360 }

        let n = wheel.segments.count
        let segDeg = 360.0 / Double(n)
        // Shift by half a segment so segment 0 is centred at 0° (12 o'clock).
        let idx = Int((deg + segDeg / 2).truncatingRemainder(dividingBy: 360) / segDeg) % n
        state.highlightedIndex = idx
    }

    private func handleScroll(delta: CGFloat) {
        guard let idx = state.highlightedIndex else { return }
        let actions = effectiveActions(for: idx)
        guard actions.count > 1 else { return }

        var cur = stickyIndices[idx] ?? 0
        cur = delta < 0
            ? (cur + 1) % actions.count
            : (cur - 1 + actions.count) % actions.count
        stickyIndices[idx] = cur
        state.actionIndices = stickyIndices
    }

    /// On each arrow key press, step one position along the axis toward the pressed direction.
    /// Passes through center (nil) when moving from the exact opposite segment.
    ///
    /// Axes (segment ↔ center ↔ opposite):
    ///   0 ↔ center ↔ 4  (↑ / ↓)
    ///   1 ↔ center ↔ 5  (↑→ / ↓←)
    ///   2 ↔ center ↔ 6  (→ / ←)
    ///   3 ↔ center ↔ 7  (↓→ / ↑←)
    private func stepTowardPressedDirection() {
        let up    = pressedArrows.contains(126)
        let right = pressedArrows.contains(124)
        let down  = pressedArrows.contains(125)
        let left  = pressedArrows.contains(123)

        let target: Int
        switch (up, right, down, left) {
        case (true,  false, false, false): target = 0
        case (true,  true,  false, false): target = 1
        case (false, true,  false, false): target = 2
        case (false, true,  true,  false): target = 3
        case (false, false, true,  false): target = 4
        case (false, false, true,  true):  target = 5
        case (false, false, false, true):  target = 6
        case (true,  false, false, true):  target = 7
        default: return  // no keys or opposing pair — ignore
        }

        let opposite = (target + 4) % 8

        if state.highlightedIndex == opposite {
            state.highlightedIndex = nil    // step through center
        } else {
            state.highlightedIndex = target // at center or elsewhere → jump to target
        }
    }

    /// Cancel with no action and close the wheel immediately.
    private func cancelAndClose() {
        keyDownDate = nil
        pressedArrows.removeAll()
        stopTracking()
        panel.orderOut(nil)
        backdrop.orderOut(nil)
        state.highlightedIndex = nil
    }

    /// Fire the currently highlighted segment's action and dismiss the wheel.
    private func fireCurrentSegment() {
        guard let idx = state.highlightedIndex else { return }
        let actions = effectiveActions(for: idx)
        guard !actions.isEmpty else { return }
        let actionIdx = min(stickyIndices[idx] ?? 0, actions.count - 1)

        stickyIndices[idx] = actionIdx
        lastFired = (idx, actionIdx)

        keyDownDate = nil
        stopTracking()
        panel.orderOut(nil)
        backdrop.orderOut(nil)
        state.highlightedIndex = nil

        ActionExecutor.execute(actions[actionIdx])
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Coordinate conversion
    // ─────────────────────────────────────────────────────────────────────────

    /// Converts an AppKit screen point (y-up, origin bottom-left of screen)
    /// to SwiftUI view coordinates (y-down, origin top-left of screen).
    private func toViewCoord(_ screenPoint: NSPoint, screen: NSScreen) -> CGPoint {
        CGPoint(
            x: screenPoint.x - screen.frame.origin.x,
            y: screen.frame.height - (screenPoint.y - screen.frame.origin.y)
        )
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Dynamic segments
    // ─────────────────────────────────────────────────────────────────────────

    /// Returns populated dynamic actions for `segmentIndex` if available,
    /// falling back to the segment's static actions array.
    private func effectiveActions(for segmentIndex: Int) -> [BibloAction] {
        state.dynamicActions[segmentIndex] ?? wheel.segments[segmentIndex].actions
    }

    /// For each segment with a dynamicCommand, runs that command in parallel
    /// (1-second timeout per command) and stores results in state.dynamicActions.
    /// Blocks the calling thread — call before showing the wheel.
    private func populateDynamicSegments() {
        let indexed = wheel.segments.enumerated().filter { $0.element.dynamicCommand != nil }
        guard !indexed.isEmpty else { return }

        let group = DispatchGroup()
        var results: [Int: [BibloAction]] = [:]
        let lock = NSLock()

        for (i, seg) in indexed {
            guard let raw = seg.dynamicCommand, !raw.isEmpty else { continue }
            let cmd = VariableResolver.resolve(raw)
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                let actions = self.runDynamicCommand(cmd)
                lock.lock()
                results[i] = actions
                lock.unlock()
                group.leave()
            }
        }

        // Wait up to 1 second total (per-command timeout is inside runDynamicCommand)
        _ = group.wait(timeout: .now() + 1.0)
        state.dynamicActions = results
    }

    /// Executes `command` via /bin/zsh -lc with a 1-second timeout.
    /// Each non-empty output line becomes a runShell action.
    /// Returns at most 8 actions (wheel segment limit).
    private func runDynamicCommand(_ command: String) -> [BibloAction] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments     = ["-lc", command]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError  = Pipe()  // discard stderr

        guard (try? task.run()) != nil else { return [] }

        // Poll with 1-second deadline
        let deadline = Date().addingTimeInterval(1.0)
        while task.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        if task.isRunning { task.terminate() }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        // ponytail: LABEL|CMD format deferred — add when first user requests custom display labels
        return output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .prefix(8)
            .map { BibloAction.runShell(command: String($0), captureOutput: false) }
    }
}
