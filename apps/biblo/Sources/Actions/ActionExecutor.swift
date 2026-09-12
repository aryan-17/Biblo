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
            task.arguments     = ["-lc", command]  // -l loads user profile
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

        // ── v1 actions (stubs — wire up in v1) ───────────────────────────────
        case .sendKeystroke(let combo):
            NSLog("Biblo: sendKeystroke not yet implemented — \(combo)")

        case .runAppleScript(let source):
            guard let script = NSAppleScript(source: source) else { return }
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if let err = error { NSLog("Biblo: AppleScript error — \(err)") }
        }
    }
}
