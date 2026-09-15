import AppKit
import Foundation

/// Replaces {{tokens}} in template strings with live system values.
enum VariableResolver {

    /// Resolves all supported {{tokens}} in `template`.
    static func resolve(_ template: String) -> String {
        guard template.contains("{{") else { return template }   // fast path
        var result = template
        result = result.replacingOccurrences(of: "{{clipboard}}",       with: clipboard())
        result = result.replacingOccurrences(of: "{{frontapp.bundle}}", with: frontAppBundle())
        result = result.replacingOccurrences(of: "{{date}}",            with: isoDate())
        result = result.replacingOccurrences(of: "{{time}}",            with: currentTime())
        return result
    }

    // ── Token providers ───────────────────────────────────────────────────────

    private static func clipboard() -> String {
        NSPasteboard.general.string(forType: .string) ?? ""
    }

    private static func frontAppBundle() -> String {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
    }

    private static func isoDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private static func currentTime() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }
}
