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
                let action = seg.actions[min(last.actionIdx, seg.actions.count - 1)]
                ActionExecutor.execute(action)
            }
            return
        }

        guard let idx = state.highlightedIndex else { return }  // dead zone = cancel

        let seg = wheel.segments[idx]
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

        // Keyboard navigation — local monitor works because panel is now key window.
        // Returns nil to consume arrow/return keys (prevents them reaching other responders).
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            switch event.keyCode {
            case 123: self.cycleSegment(by: -1);    return nil  // ← counter-clockwise
            case 124: self.cycleSegment(by:  1);    return nil  // → clockwise
            case 126: self.handleScroll(delta:  1); return nil  // ↑ previous action
            case 125: self.handleScroll(delta: -1); return nil  // ↓ next action
            case 36, 76:                                        // Return / numpad Enter
                self.fireCurrentSegment();          return nil
            default:
                // 1–8 jump directly to segment
                if let ch = event.characters, let n = Int(ch), (1...8).contains(n) {
                    self.state.highlightedIndex = n - 1
                    return nil
                }
                return event
            }
        }

        // Seed immediately so the first frame is correct
        updateFromCursor()
    }

    private func stopTracking() {
        [mouseMonitor, scrollMonitor, keyMonitor].compactMap { $0 }.forEach {
            NSEvent.removeMonitor($0)
        }
        mouseMonitor  = nil
        scrollMonitor = nil
        keyMonitor    = nil
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

    /// Rotate highlighted segment by delta (positive = clockwise).
    private func cycleSegment(by delta: Int) {
        let count = wheel.segments.count
        let current = state.highlightedIndex ?? (delta > 0 ? count - 1 : 0)
        state.highlightedIndex = (current + delta + count) % count
    }

    /// Fire the currently highlighted segment's action and dismiss the wheel.
    private func fireCurrentSegment() {
        guard let idx = state.highlightedIndex else { return }
        let seg = wheel.segments[idx]
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
