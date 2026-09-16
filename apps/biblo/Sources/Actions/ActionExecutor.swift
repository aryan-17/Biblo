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

    /// Opens a new tab in the target terminal app and runs `command`.
    /// Prompts for Accessibility permission if not already granted.
    private static func openInTerminalTab(command: String, terminalBundleID: String) {
        // Check Accessibility — prompt if missing, then bail (user retries after grant)
        guard AXIsProcessTrusted() else {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(opts as CFDictionary)
            NSLog("Biblo: Accessibility not granted — prompted user")
            return
        }

        // Use localizedName from running instance (most reliable for System Events)
        let appName = NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == terminalBundleID }?
            .localizedName ?? TerminalApps.processName(for: terminalBundleID)

        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "\(appName)" to activate
        delay 0.35
        tell application "System Events"
            tell process "\(appName)"
                keystroke "t" using command down
                delay 0.2
                keystroke "\(escaped)"
                key code 36
            end tell
        end tell
        """

        DispatchQueue.global(qos: .userInitiated).async {
            guard let appleScript = NSAppleScript(source: script) else { return }
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let err = error { NSLog("Biblo: runInTerminal error — \(err)") }
        }
    }
}
