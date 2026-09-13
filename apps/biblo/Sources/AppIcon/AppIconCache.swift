import AppKit

/// Thread-safe cache for app bundle icons.
/// Keyed by bundle ID; misses fall back to SF Symbol placeholder.
final class AppIconCache {
    static let shared = AppIconCache()
    private var cache: [String: NSImage] = [:]

    func icon(forBundleID bundleID: String) -> NSImage? {
        if let hit = cache[bundleID] { return hit }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        let img = NSWorkspace.shared.icon(forFile: url.path)
        cache[bundleID] = img
        return img
    }

    func invalidate(bundleID: String) {
        cache.removeValue(forKey: bundleID)
    }
}
