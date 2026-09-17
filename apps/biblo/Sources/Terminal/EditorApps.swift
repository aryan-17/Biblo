import Foundation

/// Known code editor bundle IDs and their CLI tools.
enum EditorApps {

    static let knownBundleIDs: Set<String> = [
        "com.todesktop.230313mzl4w4u92",  // Cursor
        "com.microsoft.VSCode",            // VS Code
        "com.jetbrains.intellij",          // IntelliJ IDEA
        "com.apple.dt.Xcode",             // Xcode
        "com.jetbrains.WebStorm",         // WebStorm
        "com.jetbrains.PyCharm",          // PyCharm
        "com.sublimetext.4",              // Sublime Text
        "io.zed.zed",                     // Zed
        "com.jetbrains.goland",           // GoLand
        "com.jetbrains.rubymine",         // RubyMine
        "com.jetbrains.datagrip",         // DataGrip
    ]

    /// CLI candidates per bundle ID. First existing executable wins.
    private static let cliCandidates: [String: [String]] = [
        "com.todesktop.230313mzl4w4u92": [
            "/usr/local/bin/cursor",
            "/Applications/Cursor.app/Contents/Resources/app/bin/cursor",
        ],
        "com.microsoft.VSCode": [
            "/usr/local/bin/code",
            "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code",
        ],
        "com.jetbrains.intellij": ["/usr/local/bin/idea"],
        "com.jetbrains.WebStorm": ["/usr/local/bin/webstorm"],
        "com.jetbrains.PyCharm": ["/usr/local/bin/pycharm"],
        "com.jetbrains.goland": ["/usr/local/bin/goland"],
        "io.zed.zed": ["/usr/local/bin/zed"],
    ]

    static func isEditor(bundleID: String) -> Bool {
        knownBundleIDs.contains(bundleID)
    }

    /// Returns a path to the editor's CLI tool if available.
    /// CLI tools support --reuse-window to focus existing window rather than opening a new one.
    static func cliPath(for bundleID: String) -> String? {
        cliCandidates[bundleID]?.first {
            FileManager.default.isExecutableFile(atPath: $0)
        }
    }
}
