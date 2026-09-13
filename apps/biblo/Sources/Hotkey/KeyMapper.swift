import Carbon.HIToolbox

/// Maps human-readable key names and modifier strings to Carbon values.
enum KeyMapper {

    /// Convert a key name string to a Carbon virtual key code.
    /// Case-insensitive. Returns nil if unknown.
    static func keyCode(for key: String) -> UInt32? {
        codes[key.lowercased()]
    }

    /// Convert an array of modifier name strings to a Carbon modifier mask.
    /// Supported values: "option"/"alt", "command"/"cmd", "control"/"ctrl", "shift"
    static func modifiers(from strings: [String]) -> UInt32 {
        strings.reduce(0) { mask, mod in
            switch mod.lowercased() {
            case "option", "alt":   return mask | UInt32(optionKey)
            case "command", "cmd":  return mask | UInt32(cmdKey)
            case "control", "ctrl": return mask | UInt32(controlKey)
            case "shift":           return mask | UInt32(shiftKey)
            default:                return mask
            }
        }
    }

    // ── Carbon virtual key code table ─────────────────────────────────────────
    private static let codes: [String: UInt32] = [
        // Special
        "space": 49, "return": 36, "tab": 48, "delete": 51,
        "escape": 53, "esc": 53,
        "left": 123, "right": 124, "down": 125, "up": 126,
        "pageup": 116, "pagedown": 121, "home": 115, "end": 119,

        // Function keys
        "f1": 122, "f2": 120, "f3": 99,  "f4": 118,
        "f5": 96,  "f6": 97,  "f7": 98,  "f8": 100,
        "f9": 101, "f10": 109,"f11": 103, "f12": 111,
        "f13": 105,"f14": 107,"f15": 113,

        // Letters
        "a": 0,  "s": 1,  "d": 2,  "f": 3,  "h": 4,
        "g": 5,  "z": 6,  "x": 7,  "c": 8,  "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "o": 31, "u": 32, "i": 34,
        "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,

        // Numbers
        "1": 18, "2": 19, "3": 20, "4": 21, "5": 23,
        "6": 22, "7": 26, "8": 28, "9": 25, "0": 29,

        // Punctuation
        "-": 27, "=": 24, "[": 33, "]": 30, "\\": 42,
        ";": 41, "'": 39, ",": 43, ".": 47, "/": 44,
        "`": 50,
    ]
}
