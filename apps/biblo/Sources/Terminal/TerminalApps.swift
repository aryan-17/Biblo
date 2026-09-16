import AppKit

/// Known terminal emulator bundle IDs and helpers.
enum TerminalApps {

    static let knownBundleIDs: Set<String> = [
        "dev.warp.Warp-Stable",
        "dev.warp.Warp",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "net.kovidgoyal.kitty",
        "io.alacritty",
        "com.github.wez.wezterm",
    ]

    static func isTerminal(bundleID: String) -> Bool {
        knownBundleIDs.contains(bundleID)
    }

    /// Resolves the process name used by System Events from a bundle ID.
    /// Falls back to "Terminal" if the app isn't installed.
    static func processName(for bundleID: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?
            .deletingPathExtension().lastPathComponent ?? "Terminal"
    }
}
