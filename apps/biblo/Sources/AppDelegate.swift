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

        // ── Accessibility check (required for terminal commands) ──────────────
        if !AXIsProcessTrusted() {
            let wheel = wheelController.currentWheel
            let hasTerminal = wheel.segments.contains {
                $0.actions.contains { if case .runInTerminal = $0 { return true }; return false }
            }
            if hasTerminal {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let alert = NSAlert()
                    alert.messageText     = "Accessibility Required"
                    alert.informativeText = "Biblo needs Accessibility to open terminal tabs.\n\n1. Click \"Open Settings\"\n2. Add Biblo to the list and enable it\n3. Quit and relaunch Biblo"
                    alert.alertStyle      = .warning
                    alert.addButton(withTitle: "Open Settings")
                    alert.addButton(withTitle: "Later")
                    NSApp.activate(ignoringOtherApps: true)
                    if alert.runModal() == .alertFirstButtonReturn {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        )
                    }
                }
            }
        }

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
