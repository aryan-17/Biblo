import AppKit
import Carbon.HIToolbox
import SwiftUI

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

    // ── Timing ────────────────────────────────────────────────────────────────
    private var keyDownDate: Date?
    private let tapThreshold: TimeInterval = 0.18

    // ── Screen where cursor was on keydown ────────────────────────────────────
    private var activeScreen: NSScreen?

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
                let seg = wheel.segments[last.segmentIdx]
                guard !seg.actions.isEmpty else { return }
                let action = seg.actions[min(last.actionIdx, seg.actions.count - 1)]
                ActionExecutor.execute(action)
            }
            return
        }

        guard let idx = state.highlightedIndex else { return }  // dead zone = cancel

        let seg = wheel.segments[idx]
        guard !seg.actions.isEmpty else { return }
        let actionIdx = min(stickyIndices[idx] ?? 0, seg.actions.count - 1)
        let action = seg.actions[actionIdx]

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

        // Key-down: track arrows for diagonal combos; handle non-arrow keys.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            switch event.keyCode {
            case 123, 124, 125, 126:              // arrow keys
                self.pressedArrows.insert(event.keyCode)
                self.updateSegmentFromArrows()
                return nil
            case 53:                              // Esc → dead zone (cancel on release)
                self.pressedArrows.removeAll()
                self.state.highlightedIndex = nil
                return nil
            case 36, 76:                          // Return / numpad Enter
                self.fireCurrentSegment()
                return nil
            default:
                if let ch = event.characters, let n = Int(ch), (1...8).contains(n) {
                    self.state.highlightedIndex = n - 1
                    return nil
                }
                return event
            }
        }

        // Key-up: remove arrow from set, recompute direction.
        keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard let self = self else { return event }
            if [123, 124, 125, 126].contains(event.keyCode) {
                self.pressedArrows.remove(event.keyCode)
                self.updateSegmentFromArrows()
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
        let seg = wheel.segments[idx]
        guard seg.actions.count > 1 else { return }

        var cur = stickyIndices[idx] ?? 0
        cur = delta < 0
            ? (cur + 1) % seg.actions.count
            : (cur - 1 + seg.actions.count) % seg.actions.count
        stickyIndices[idx] = cur
        state.actionIndices = stickyIndices
    }

    /// Compute highlighted segment from the set of held arrow keys.
    /// Segment 0=↑, 1=↑→, 2=→, 3=↓→, 4=↓, 5=↓←, 6=←, 7=↑←
    private func updateSegmentFromArrows() {
        let up    = pressedArrows.contains(126)
        let right = pressedArrows.contains(124)
        let down  = pressedArrows.contains(125)
        let left  = pressedArrows.contains(123)

        switch (up, right, down, left) {
        case (true,  false, false, false): state.highlightedIndex = 0
        case (true,  true,  false, false): state.highlightedIndex = 1
        case (false, true,  false, false): state.highlightedIndex = 2
        case (false, true,  true,  false): state.highlightedIndex = 3
        case (false, false, true,  false): state.highlightedIndex = 4
        case (false, false, true,  true):  state.highlightedIndex = 5
        case (false, false, false, true):  state.highlightedIndex = 6
        case (true,  false, false, true):  state.highlightedIndex = 7
        case (false, false, false, false): break  // no arrows held — mouse controls
        default: break                            // opposing keys (↑↓ or ←→) — ignore
        }
    }

    /// Fire the currently highlighted segment's action and dismiss the wheel.
    private func fireCurrentSegment() {
        guard let idx = state.highlightedIndex else { return }
        let seg = wheel.segments[idx]
        guard !seg.actions.isEmpty else { return }
        let actionIdx = min(stickyIndices[idx] ?? 0, seg.actions.count - 1)

        stickyIndices[idx] = actionIdx
        lastFired = (idx, actionIdx)

        keyDownDate = nil
        stopTracking()
        panel.orderOut(nil)
        backdrop.orderOut(nil)
        state.highlightedIndex = nil

        ActionExecutor.execute(seg.actions[actionIdx])
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
}
