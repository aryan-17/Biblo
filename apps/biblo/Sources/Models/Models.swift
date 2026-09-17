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
}

enum SegmentType: String, Codable {
    case appOnly
    case actionOnly
    case appWithActions
}

// ─── Action ───────────────────────────────────────────────────────────────────

enum BibloAction: Codable {
    case launchApp(bundleID: String)
    case runShell(command: String)
    case runShortcut(name: String)
    case openURL(url: String, label: String?)
    case sendKeystroke(keyCombo: String)
    case runAppleScript(source: String)
    case openFile(path: String)
    case runInTerminal(command: String, terminalBundleID: String)
    case openProject(path: String, editorBundleID: String)

    private enum CodingKeys: String, CodingKey {
        case type, bundleID, command, name, url, label, keyCombo, source, path, terminalBundleID, editorBundleID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "launchApp":      self = .launchApp(bundleID: try c.decode(String.self, forKey: .bundleID))
        case "runShell":       self = .runShell(command: try c.decode(String.self, forKey: .command))
        case "runShortcut":    self = .runShortcut(name: try c.decode(String.self, forKey: .name))
        case "openURL":
            let url   = try c.decode(String.self, forKey: .url)
            let label = try? c.decode(String.self, forKey: .label)
            self = .openURL(url: url, label: label)
        case "sendKeystroke":  self = .sendKeystroke(keyCombo: try c.decode(String.self, forKey: .keyCombo))
        case "runAppleScript": self = .runAppleScript(source: try c.decode(String.self, forKey: .source))
        case "openFile":       self = .openFile(path: try c.decode(String.self, forKey: .path))
        case "runInTerminal":
            let cmd = try c.decode(String.self, forKey: .command)
            let tid = try c.decode(String.self, forKey: .terminalBundleID)
            self = .runInTerminal(command: cmd, terminalBundleID: tid)
        case "openProject":
            let p  = try c.decode(String.self, forKey: .path)
            let eid = try c.decode(String.self, forKey: .editorBundleID)
            self = .openProject(path: p, editorBundleID: eid)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c,
                debugDescription: "Unknown action type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .launchApp(let v):      try c.encode("launchApp", forKey: .type);      try c.encode(v, forKey: .bundleID)
        case .runShell(let v):       try c.encode("runShell", forKey: .type);       try c.encode(v, forKey: .command)
        case .runShortcut(let v):    try c.encode("runShortcut", forKey: .type);    try c.encode(v, forKey: .name)
        case .openURL(let url, let lbl):
            try c.encode("openURL", forKey: .type)
            try c.encode(url, forKey: .url)
            if let lbl { try c.encode(lbl, forKey: .label) }
        case .sendKeystroke(let v):  try c.encode("sendKeystroke", forKey: .type);  try c.encode(v, forKey: .keyCombo)
        case .runAppleScript(let v): try c.encode("runAppleScript", forKey: .type); try c.encode(v, forKey: .source)
        case .openFile(let v):       try c.encode("openFile", forKey: .type);       try c.encode(v, forKey: .path)
        case .runInTerminal(let cmd, let tid):
            try c.encode("runInTerminal", forKey: .type)
            try c.encode(cmd, forKey: .command)
            try c.encode(tid, forKey: .terminalBundleID)
        case .openProject(let p, let eid):
            try c.encode("openProject", forKey: .type)
            try c.encode(p, forKey: .path)
            try c.encode(eid, forKey: .editorBundleID)
        }
    }

    /// Short display string for sub-label in level-2 segments
    var displayLabel: String {
        switch self {
        case .launchApp:                   return "Launch"
        case .runShell(let cmd):          return String(cmd.prefix(24))
        case .runShortcut(let name):      return name
        case .openURL(let url, let lbl):
            if let lbl, !lbl.isEmpty { return lbl }
            return URL(string: url)?.host ?? String(url.prefix(24))
        case .sendKeystroke(let k):       return k
        case .runAppleScript:             return "AppleScript"
        case .openFile(let path):         return URL(fileURLWithPath: path).lastPathComponent
        case .runInTerminal(let cmd, _):  return String(cmd.prefix(24))
        case .openProject(let path, _):
            let expanded = (path as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expanded).lastPathComponent
        }
    }
}
