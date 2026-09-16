import AppKit
import Foundation

enum ActionExecutor {

    static func execute(_ action: BibloAction) {
        switch action {

        case .launchApp(let bundleID):
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                NSLog("Biblo: app not found — \(bundleID)")
                return
            }
            NSWorkspace.shared.openApplication(
                at: url,
                configuration: NSWorkspace.OpenConfiguration()
            )

        case .runShell(let command):
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            task.arguments     = ["-lc", command]
            try? task.run()

        case .runShortcut(let name):
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            task.arguments     = ["run", name]
            try? task.run()

        case .openURL(let urlString):
            guard let url = URL(string: urlString) else { return }
            NSWorkspace.shared.open(url)

        case .openFile(let path):
            NSWorkspace.shared.open(URL(fileURLWithPath: path))

        case .sendKeystroke(let combo):
            NSLog("Biblo: sendKeystroke not yet implemented — \(combo)")

        case .runAppleScript(let source):
            guard let script = NSAppleScript(source: source) else { return }
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if let err = error { NSLog("Biblo: AppleScript error — \(err)") }

        case .runInTerminal(let command, let terminalBundleID):
            openInTerminalTab(command: command, terminalBundleID: terminalBundleID)
        }
    }

    // ── Terminal tab opener ───────────────────────────────────────────────────

    /// Activates terminal via NSWorkspace (no Automation permission),
    /// then uses System Events only for new-tab + command (one-time dialog).
    private static func openInTerminalTab(command: String, terminalBundleID: String) {
        let appName = NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == terminalBundleID }?
            .localizedName ?? TerminalApps.processName(for: terminalBundleID)

        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        DispatchQueue.global(qos: .userInitiated).async {
            // Activate via NSWorkspace — no Automation permission needed
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalBundleID) {
                NSWorkspace.shared.openApplication(
                    at: appURL,
                    configuration: NSWorkspace.OpenConfiguration()
                )
            }

            // Wait for app to become frontmost
            Thread.sleep(forTimeInterval: 0.5)

            // System Events only — triggers one Automation dialog, then permanent
            let script = """
            tell application "System Events"
                tell process "\(appName)"
                    keystroke "t" using command down
                    delay 0.25
                    keystroke "\(escaped)"
                    key code 36
                end tell
            end tell
            """

            guard let appleScript = NSAppleScript(source: script) else { return }
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let err = error { NSLog("Biblo: runInTerminal error — \(err)") }
        }
    }
}
