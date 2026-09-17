import Foundation

/// Known code editor bundle IDs.
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

    static func isEditor(bundleID: String) -> Bool {
        knownBundleIDs.contains(bundleID)
    }
}
