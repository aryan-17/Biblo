import Foundation

enum ConfigLoader {

    static var configURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/biblo/wheels.json")
    }

    /// Writes the wheel back to disk (background thread, best-effort).
    static func save(_ wheel: Wheel) {
        let config = WheelConfig(wheels: [wheel])
        DispatchQueue.global(qos: .utility).async {
            guard let data = try? JSONEncoder().encode(config) else { return }
            // Pretty-print
            if let obj = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted) {
                try? pretty.write(to: configURL, options: .atomic)
            } else {
                try? data.write(to: configURL, options: .atomic)
            }
        }
    }

    /// Loads config from disk; returns a built-in default wheel if file missing or malformed.
    static func load() -> Wheel {
        if let data = try? Data(contentsOf: configURL),
           let config = try? JSONDecoder().decode(WheelConfig.self, from: data),
           let first = config.wheels.first {
            return first
        }
        return defaultWheel()
    }

    static func defaultWheel() -> Wheel {
        Wheel(
            id: "main",
            hotkey: HotkeyConfig(key: "Space", modifiers: ["option"]),
            segments: [
                seg("Terminal",  icon: "terminal",           action: .runShell(command: "open -a Terminal")),
                seg("Browser",   icon: "safari",             action: .launchApp(bundleID: "com.apple.Safari")),
                seg("Finder",    icon: "folder",             action: .launchApp(bundleID: "com.apple.finder")),
                seg("Mail",      icon: "envelope",           action: .launchApp(bundleID: "com.apple.mail")),
                seg("Music",     icon: "music.note",         action: .launchApp(bundleID: "com.apple.Music")),
                seg("Notes",     icon: "note.text",          action: .launchApp(bundleID: "com.apple.Notes")),
                seg("Calendar",  icon: "calendar",           action: .launchApp(bundleID: "com.apple.iCal")),
                seg("Settings",  icon: "gearshape",          action: .launchApp(bundleID: "com.apple.systempreferences")),
            ]
        )
    }

    private static func seg(_ label: String, icon: String, action: BibloAction) -> Segment {
        Segment(label: label, icon: icon, type: .actionOnly, stickyIndex: 0, actions: [action])
    }
}
