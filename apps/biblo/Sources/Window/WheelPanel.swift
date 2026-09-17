import AppKit

/// Full-screen transparent panel that hosts the wheel UI.
///
/// Two invariants that must never break:
/// 1. `.nonactivatingPanel` — the frontmost app must not change when the wheel appears.
/// 2. Created once at launch, reused on every invocation. Never recreated.
final class WheelPanel: NSPanel {

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        level             = .floating
        isOpaque          = false
        backgroundColor   = .clear
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        isMovable          = false
        isReleasedWhenClosed = false
        hasShadow          = false
    }

    // Allow the panel to become key without activating the app,
    // so global event monitors fire reliably.
    override var canBecomeKey:  Bool { true }
    override var canBecomeMain: Bool { false }

    // Swallow all key equivalents (⌘, etc.) while the wheel is visible.
    // Prevents ⌘, from escaping to the status bar menu and opening Preferences.
    override func performKeyEquivalent(with event: NSEvent) -> Bool { true }
}
