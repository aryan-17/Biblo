import Foundation

/// Known browser and communication app bundle IDs.
enum BrowserApps {

    static let knownBundleIDs: Set<String> = [
        // Browsers
        "com.brave.Browser",
        "company.thebrowser.Browser",     // Arc
        "com.apple.Safari",
        "com.google.Chrome",
        "org.mozilla.firefox",
        "com.microsoft.edgemac",
        "com.operasoftware.Opera",
        // Communication / productivity
        "com.tinyspeck.slackmacgap",      // Slack
        "com.linear",                      // Linear
        "com.notion.id",                   // Notion
        "com.superhuman.Superhuman",       // Superhuman
        "com.readdle.smartemail",          // Spark
        "ru.keepcoder.Telegram",           // Telegram
    ]

    static func isBrowser(bundleID: String) -> Bool {
        knownBundleIDs.contains(bundleID)
    }
}
