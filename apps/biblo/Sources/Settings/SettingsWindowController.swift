import AppKit
import SwiftUI

/// Singleton settings window. Calling `show` brings it to front if already open.
final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    private static var instance: SettingsWindowController?

    static func show(wheel: Wheel, onSave: @escaping (Wheel) -> Void) {
        if let existing = instance {
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let controller = SettingsWindowController(wheel: wheel, onSave: onSave)
        instance = controller
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private init(wheel: Wheel, onSave: @escaping (Wheel) -> Void) {
        let view = SettingsView(wheel: wheel, onSave: { updatedWheel in
            onSave(updatedWheel)
        })
        let hosting = NSHostingController(rootView: view)
        hosting.view.appearance = NSAppearance(named: .darkAqua)

        let window = NSWindow(contentViewController: hosting)
        window.title          = "Biblo — Preferences"
        window.styleMask      = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 520, height: 520))
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    func windowWillClose(_ notification: Notification) {
        SettingsWindowController.instance = nil
    }
}
