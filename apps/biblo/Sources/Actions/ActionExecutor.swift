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

    /// Opens a new Warp tab running `command`.
    /// Writes a .command script and opens it with the terminal app.
    /// No Automation or Accessibility permission required.
    private static func openInTerminalTab(command: String, terminalBundleID: String) {
        guard let warpURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: terminalBundleID) else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            // .command extension → Warp opens in a new tab and executes.
            // -il: interactive login shell so aliases, PATH, and functions are loaded.
            let tmp = URL(fileURLWithPath: "/tmp/biblo_\(Int(Date().timeIntervalSince1970)).command")
            let content = "#!/bin/zsh -il\ntrap 'rm -f \(tmp.path)' EXIT\n\(command)\n"
            try? content.write(to: tmp, atomically: true, encoding: .utf8)
            try? FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: tmp.path)

            NSWorkspace.shared.open(
                [tmp], withApplicationAt: warpURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
        }
    }
}
