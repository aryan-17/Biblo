import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let wheelController = WheelController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ── Status bar icon ───────────────────────────────────────────────────
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "circle.hexagongrid.fill",
                accessibilityDescription: "Biblo"
            )
            button.image?.size = NSSize(width: 16, height: 16)
        }
        statusItem.menu = buildMenu()

        // ── Wheel (creates panel, registers hotkey) ───────────────────────────
        wheelController.setup()

        NSLog("Biblo: ready. F13 to open wheel.")
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Menu
    // ─────────────────────────────────────────────────────────────────────────

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let title = NSMenuItem(title: "Biblo", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        menu.addItem(.separator())

        menu.addItem(
            NSMenuItem(
                title: "Preferences…",
                action: #selector(openPreferences),
                keyEquivalent: ","
            )
        )

        menu.addItem(
            NSMenuItem(
                title: "Reload Config",
                action: #selector(reloadConfig),
                keyEquivalent: "r"
            )
        )

        menu.addItem(.separator())

        menu.addItem(
            NSMenuItem(
                title: "Quit Biblo",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )

        return menu
    }

    @objc private func openPreferences() {
        SettingsWindowController.show(wheel: wheelController.currentWheel) { [weak self] updated in
            self?.wheelController.apply(updated)
        }
    }

    @objc private func reloadConfig() {
        // TODO: wire to WheelController.reloadConfig()
        NSLog("Biblo: reload config")
    }
}
