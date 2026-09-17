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

        // Haptic feedback on segment change and outer ring selection change
        state.$highlightedIndex
            .dropFirst()
            .removeDuplicates()
            .sink { _ in
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
            }
            .store(in: &cancellables)

        state.$outerSelectedIndex
            .dropFirst()
            .removeDuplicates()
            .sink { _ in
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
            }
            .store(in: &cancellables)

        // Register hotkey
        hotkeyMgr.onKeyDown = { [weak self] in self?.handleKeyDown() }
        hotkeyMgr.onKeyUp   = { [weak self] in self?.handleKeyUp()   }

        let keyCode   = KeyMapper.keyCode(for: wheel.hotkey.key) ?? 49
        let modifiers = KeyMapper.modifiers(from: wheel.hotkey.modifiers)
        hotkeyMgr.register(keyCode: keyCode, modifiers: modifiers)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Key events
    // ─────────────────────────────────────────────────────────────────────────

    private func handleKeyDown() {
        keyDownDate = Date()
        let cursor = NSEvent.mouseLocation

        activeScreen = NSScreen.screens.first { $0.frame.contains(cursor) } ?? NSScreen.main

        guard let screen = activeScreen else { return }

        panel.setFrame(screen.frame,    display: false)
        backdrop.setFrame(screen.frame, display: false)

        state.wheelOrigin = toViewCoord(cursor, screen: screen)
        state.highlightedIndex = nil

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
                let seg = wheel.segments[last.segmentIdx]
                guard !seg.actions.isEmpty else { return }
                let action = seg.actions[min(last.actionIdx, seg.actions.count - 1)]
                ActionExecutor.execute(action)
            }
            return
        }

        guard let idx = state.highlightedIndex else { return }  // dead zone = cancel

        let seg     = wheel.segments[idx]
        let outerIdx = state.outerSelectedIndex

        state.highlightedIndex   = nil
        state.outerSelectedIndex = nil

        // Outer ring selected → fire that sub-command
        if let j = outerIdx {
            let subActions = seg.actions.filter {
                if case .launchApp = $0 { return false }; return true
            }
            guard j < subActions.count else { return }
            let action = subActions[j]
            // Find this action's real index in the full actions array for sticky tracking
            if let ai = seg.actions.firstIndex(where: { $0.displayLabel == action.displayLabel }) {
                stickyIndices[idx] = ai
                lastFired = (idx, ai)
            }
            ActionExecutor.execute(action)
            return
        }

        // Inner ring — normal action
        guard !seg.actions.isEmpty else { return }
        let actionIdx = min(stickyIndices[idx] ?? 0, seg.actions.count - 1)
        let action    = seg.actions[actionIdx]
        stickyIndices[idx] = actionIdx
        lastFired = (idx, actionIdx)
        ActionExecutor.execute(action)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Event monitoring
    // ─────────────────────────────────────────────────────────────────────────

    private func startTracking() {
        stopTracking()
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged]
        ) { [weak self] _ in
            self?.updateFromCursor()
        }

        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScroll(delta: event.scrollingDeltaY)
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            switch event.keyCode {
            case 123, 124, 125, 126:
                self.pressedArrows.insert(event.keyCode)
                // Left/right cycle outer ring when a terminal segment is highlighted
                if [123, 124].contains(event.keyCode),
                   let innerIdx = self.state.highlightedIndex {
                    let subCount = self.wheel.segments[innerIdx].actions.filter {
                        if case .launchApp = $0 { return false }; return true
                    }.count
                    if subCount > 0 {
                        let cur = self.state.outerSelectedIndex ?? 0
                        self.state.outerSelectedIndex = event.keyCode == 124
                            ? (cur + 1) % subCount          // right → next
                            : (cur - 1 + subCount) % subCount  // left → prev
                        return nil
                    }
                }
                self.stepTowardPressedDirection()
                return nil
            case 53:
                self.cancelAndClose()
                return nil
            case 36, 76:
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

        keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard let self = self else { return event }
            if [123, 124, 125, 126].contains(event.keyCode) {
                self.pressedArrows.remove(event.keyCode)
                return nil
            }
            return event
        }

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
        let dy = viewPos.y - origin.y
        let dist = sqrt(dx * dx + dy * dy)

        guard dist > 40 else {
            state.highlightedIndex = nil
            state.outerSelectedIndex = nil
            return
        }

        var deg = atan2(dx, -dy) * 180 / .pi
        if deg < 0 { deg += 360 }

        let n      = wheel.segments.count
        let segDeg = 360.0 / Double(n)
        let idx    = Int((deg + segDeg / 2).truncatingRemainder(dividingBy: 360) / segDeg) % n

        if dist > 160 {
            // Outer ring — freeze inner at current or computed segment
            let innerIdx = state.highlightedIndex ?? idx
            state.highlightedIndex = innerIdx

            let seg = wheel.segments[innerIdx]
            let subCount = seg.actions.filter {
                if case .launchApp = $0 { return false }; return true
            }.count

            guard subCount > 0 else { state.outerSelectedIndex = nil; return }

            // Check angle falls within the frozen segment's arc
            let segCentre = Double(innerIdx) * segDeg
            var relDeg = (deg - segCentre + 360).truncatingRemainder(dividingBy: 360)
            if relDeg > 180 { relDeg -= 360 }

            if abs(relDeg) <= segDeg / 2 {
                let normalized = (relDeg + segDeg / 2) / segDeg  // 0…1 within arc
                state.outerSelectedIndex = min(Int(normalized * Double(subCount)), subCount - 1)
            } else {
                state.outerSelectedIndex = nil
            }
        } else {
            // Inner ring — normal selection
            state.outerSelectedIndex = nil
            state.highlightedIndex   = idx
        }
    }

    private func handleScroll(delta: CGFloat) {
        guard let idx = state.highlightedIndex else { return }
        let seg = wheel.segments[idx]
        guard seg.actions.count > 1 else { return }

        var cur = stickyIndices[idx] ?? 0
        cur = delta < 0
            ? (cur + 1) % seg.actions.count
            : (cur - 1 + seg.actions.count) % seg.actions.count
        stickyIndices[idx] = cur
        state.actionIndices = stickyIndices
    }

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
        default: return
        }

        let opposite = (target + 4) % 8

        if state.highlightedIndex == opposite {
            state.highlightedIndex = nil
        } else {
            state.highlightedIndex = target
        }
    }

    private func cancelAndClose() {
        keyDownDate = nil
        pressedArrows.removeAll()
        stopTracking()
        panel.orderOut(nil)
        backdrop.orderOut(nil)
        state.highlightedIndex   = nil
        state.outerSelectedIndex = nil
    }

    private func fireCurrentSegment() {
        guard let idx = state.highlightedIndex else { return }
        let seg      = wheel.segments[idx]
        let outerIdx = state.outerSelectedIndex

        keyDownDate = nil
        stopTracking()
        panel.orderOut(nil)
        backdrop.orderOut(nil)
        state.highlightedIndex   = nil
        state.outerSelectedIndex = nil

        // Outer ring selected via arrow keys → fire sub-command
        if let j = outerIdx {
            let subActions = seg.actions.filter {
                if case .launchApp = $0 { return false }; return true
            }
            guard j < subActions.count else { return }
            ActionExecutor.execute(subActions[j])
            return
        }

        guard !seg.actions.isEmpty else { return }
        let actionIdx = min(stickyIndices[idx] ?? 0, seg.actions.count - 1)
        stickyIndices[idx] = actionIdx
        lastFired = (idx, actionIdx)
        ActionExecutor.execute(seg.actions[actionIdx])
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Coordinate conversion
    // ─────────────────────────────────────────────────────────────────────────

    private func toViewCoord(_ screenPoint: NSPoint, screen: NSScreen) -> CGPoint {
        CGPoint(
            x: screenPoint.x - screen.frame.origin.x,
            y: screen.frame.height - (screenPoint.y - screen.frame.origin.y)
        )
    }
}
