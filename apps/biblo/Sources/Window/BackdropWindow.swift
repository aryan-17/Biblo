import AppKit

/// Full-screen dimmed backdrop behind the wheel.
/// Sits one level below the WheelPanel. Ignores all mouse events.
final class BackdropWindow: NSWindow {

    init() {
        super.init(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: true
        )
        // One level below floating so it sits behind the wheel panel
        level             = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
        isOpaque          = false
        backgroundColor   = NSColor.black.withAlphaComponent(0.48)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        hasShadow          = false
    }
}
