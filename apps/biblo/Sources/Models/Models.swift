import Foundation

// ─── Config root ─────────────────────────────────────────────────────────────

struct WheelConfig: Codable {
    var wheels: [Wheel]
}

// ─── Wheel ────────────────────────────────────────────────────────────────────

struct Wheel: Codable {
    var id: String
    var hotkey: HotkeyConfig
    var segments: [Segment]
}

struct HotkeyConfig: Codable {
    var key: String
    var modifiers: [String]
}

// ─── Segment ──────────────────────────────────────────────────────────────────

struct Segment: Codable {
    var label: String
    var icon: String          // SF Symbol name
    var type: SegmentType
    var stickyIndex: Int
    var actions: [BibloAction]
    var dynamicCommand: String?  // if set, populated at wheel-open time; overrides actions
}

enum SegmentType: String, Codable {
    case appOnly
    case actionOnly
    case appWithActions
}

// ─── Action ───────────────────────────────────────────────────────────────────

enum BibloAction: Codable {
    case launchApp(bundleID: String)
    case runShell(command: String, captureOutput: Bool)
    case runShortcut(name: String)
    case openURL(url: String)
    case sendKeystroke(keyCombo: String)
    case runAppleScript(source: String)
    case openFile(path: String)

    private enum CodingKeys: String, CodingKey {
        case type, bundleID, command, name, url, keyCombo, source, path, captureOutput
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "launchApp":   self = .launchApp(bundleID: try c.decode(String.self, forKey: .bundleID))
        case "runShell":
            let cmd     = try c.decode(String.self, forKey: .command)
            let capture = (try? c.decode(Bool.self, forKey: .captureOutput)) ?? false
            self = .runShell(command: cmd, captureOutput: capture)
        case "runShortcut": self = .runShortcut(name: try c.decode(String.self, forKey: .name))
        case "openURL":     self = .openURL(url: try c.decode(String.self, forKey: .url))
        case "sendKeystroke": self = .sendKeystroke(keyCombo: try c.decode(String.self, forKey: .keyCombo))
        case "runAppleScript": self = .runAppleScript(source: try c.decode(String.self, forKey: .source))
        case "openFile":    self = .openFile(path: try c.decode(String.self, forKey: .path))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c,
                debugDescription: "Unknown action type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .launchApp(let v):    try c.encode("launchApp", forKey: .type);    try c.encode(v, forKey: .bundleID)
        case .runShell(let cmd, let capture):
            try c.encode("runShell", forKey: .type)
            try c.encode(cmd, forKey: .command)
            if capture { try c.encode(true, forKey: .captureOutput) }
        case .runShortcut(let v):  try c.encode("runShortcut", forKey: .type);  try c.encode(v, forKey: .name)
        case .openURL(let v):      try c.encode("openURL", forKey: .type);      try c.encode(v, forKey: .url)
        case .sendKeystroke(let v):try c.encode("sendKeystroke", forKey: .type);try c.encode(v, forKey: .keyCombo)
        case .runAppleScript(let v):try c.encode("runAppleScript", forKey: .type);try c.encode(v, forKey: .source)
        case .openFile(let v):     try c.encode("openFile", forKey: .type);     try c.encode(v, forKey: .path)
        }
    }

    /// Short display string for sub-label in level-2 segments
    var displayLabel: String {
        switch self {
        case .launchApp(let id):     return id.split(separator: ".").last.map(String.init) ?? id
        case .runShell(let cmd, _):  return String(cmd.prefix(24))
        case .runShortcut(let name): return name
        case .openURL(let url):      return url
        case .sendKeystroke(let k):  return k
        case .runAppleScript:        return "AppleScript"
        case .openFile(let path):    return URL(fileURLWithPath: path).lastPathComponent
        }
    }
}
