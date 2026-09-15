import AppKit
import Foundation

enum ActionExecutor {

    /// Execute `action`, resolving {{tokens}} in all string arguments.
    /// For `runShell(captureOutput: true)`: runs async; on completion writes
    /// stdout to clipboard (if non-empty) and calls `onCapture(stdout)`.
    /// For all other actions: synchronous fire-and-forget; `onCapture("")` called immediately.
    static func execute(_ action: BibloAction, onCapture: ((String) -> Void)? = nil) {
        switch action {

        case .launchApp(let bundleID):
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                NSLog("Biblo: app not found — \(bundleID)")
                onCapture?("")
                return
            }
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            onCapture?("")

        case .runShell(let command, let captureOutput):
            let resolved = VariableResolver.resolve(command)
            if captureOutput {
                captureShell(resolved, onCapture: onCapture)
            } else {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/bin/zsh")
                task.arguments     = ["-lc", resolved]
                try? task.run()
                onCapture?("")
            }

        case .runShortcut(let name):
            let resolved = VariableResolver.resolve(name)
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            task.arguments     = ["run", resolved]
            try? task.run()
            onCapture?("")

        case .openURL(let urlString):
            let resolved = VariableResolver.resolve(urlString)
            guard let url = URL(string: resolved) else {
                NSLog("Biblo: invalid URL — \(resolved)")
                onCapture?("")
                return
            }
            NSWorkspace.shared.open(url)
            onCapture?("")

        case .openFile(let path):
            let resolved = VariableResolver.resolve(path)
            NSWorkspace.shared.open(URL(fileURLWithPath: resolved))
            onCapture?("")

        case .sendKeystroke(let combo):
            NSLog("Biblo: sendKeystroke not yet implemented — \(combo)")
            onCapture?("")

        case .runAppleScript(let source):
            let resolved = VariableResolver.resolve(source)
            guard let script = NSAppleScript(source: resolved) else {
                onCapture?("")
                return
            }
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if let err = error { NSLog("Biblo: AppleScript error — \(err)") }
            onCapture?("")
        }
    }

    // ── Private ───────────────────────────────────────────────────────────────

    /// Runs `command` in /bin/zsh, captures stdout, writes to clipboard, calls completion on main.
    private static func captureShell(_ command: String, onCapture: ((String) -> Void)?) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            task.arguments     = ["-lc", command]
            let outPipe = Pipe()
            task.standardOutput = outPipe
            task.standardError  = Pipe()   // discard stderr

            guard (try? task.run()) != nil else {
                DispatchQueue.main.async { onCapture?("") }
                return
            }
            task.waitUntilExit()

            let data   = outPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            DispatchQueue.main.async {
                if !output.isEmpty {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output, forType: .string)
                }
                onCapture?(output)
            }
        }
    }
}
