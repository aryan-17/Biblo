import AppKit
import Foundation

func bibloLog(_ msg: String) {
    let line = "\(Date()): \(msg)\n"
    if let data = line.data(using: .utf8) {
        let url = URL(fileURLWithPath: "/tmp/biblo_debug.log")
        if let fh = try? FileHandle(forWritingTo: url) {
            fh.seekToEndOfFile(); fh.write(data); try? fh.close()
        } else {
            try? data.write(to: url)
        }
    }
    NSLog("Biblo: \(msg)")
}

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
            bibloLog("execute runInTerminal — \(command)")
            openInTerminalTab(command: command, terminalBundleID: terminalBundleID)
        }
    }

    // ── Terminal tab opener ───────────────────────────────────────────────────

    /// Activates terminal via NSWorkspace (no Automation permission),
    /// then uses System Events only for new-tab + command (one-time dialog).
    private static func openInTerminalTab(command: String, terminalBundleID: String) {
        bibloLog("openInTerminalTab — cmd=\(command) bundleID=\(terminalBundleID)")

        let appName = NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == terminalBundleID }?
            .localizedName ?? TerminalApps.processName(for: terminalBundleID)

        bibloLog("resolved appName=\(appName)")

        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        DispatchQueue.global(qos: .userInitiated).async {
            // Activate via NSWorkspace — no Automation permission needed
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalBundleID) {
                bibloLog("opening app at \(appURL)")
                NSWorkspace.shared.openApplication(
                    at: appURL,
                    configuration: NSWorkspace.OpenConfiguration()
                )
            } else {
                bibloLog("app URL not found for bundleID \(terminalBundleID)")
            }

            Thread.sleep(forTimeInterval: 0.5)

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

            bibloLog("running AppleScript for process \(appName)")
            guard let appleScript = NSAppleScript(source: script) else { return }
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let err = error {
                bibloLog("runInTerminal error — \(err)")
                let code = (err[NSAppleScript.errorNumber] as? Int) ?? 0
                if code == -1743 {
                    // Automation permission denied for System Events
                    DispatchQueue.main.async {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
                        )
                    }
                }
            } else { bibloLog("runInTerminal success") }
        }
    }
}
