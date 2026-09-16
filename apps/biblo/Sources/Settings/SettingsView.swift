import SwiftUI
import AppKit
import UniformTypeIdentifiers

// ─── SettingsView ─────────────────────────────────────────────────────────────

struct SettingsView: View {
    @State private var segments: [Segment]
    private let hotkey: HotkeyConfig
    private let onSave: (Wheel) -> Void
    private let wheelID: String

    init(wheel: Wheel, onSave: @escaping (Wheel) -> Void) {
        _segments   = State(initialValue: wheel.segments)
        hotkey      = wheel.hotkey
        wheelID     = wheel.id
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────────────────
            HStack {
                Text("Wheel Segments")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(white: 0.9))
                Spacer()
                Text("⌥Space to open")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.4))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(red: 0.09, green: 0.09, blue: 0.12))

            Divider().overlay(Color(white: 0.15))

            // ── Segment rows ─────────────────────────────────────────────────
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(segments.indices, id: \.self) { i in
                        SegmentRow(
                            index: i,
                            segment: $segments[i],
                            onPickApp: { pickApp(for: i) }
                        )
                        if i < segments.count - 1 {
                            Divider().overlay(Color(white: 0.12))
                        }
                    }
                }
            }
            .background(Color(red: 0.06, green: 0.06, blue: 0.09))

            Divider().overlay(Color(white: 0.15))

            // ── Footer ───────────────────────────────────────────────────────
            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    segments = ConfigLoader.defaultWheel().segments
                }
                .buttonStyle(PlainButtonStyle())
                .font(.system(size: 12))
                .foregroundStyle(Color(white: 0.4))

                Button("Save") {
                    save()
                }
                .buttonStyle(AccentButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(red: 0.09, green: 0.09, blue: 0.12))
        }
    }

    // ── Actions ───────────────────────────────────────────────────────────────

    private func pickApp(for index: Int) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories    = false
        panel.canChooseFiles          = true
        panel.allowedContentTypes     = [.application]
        panel.directoryURL            = URL(fileURLWithPath: "/Applications")
        panel.message                 = "Choose an application for segment \(index + 1)"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let bundle    = Bundle(url: url)
        let bundleID  = bundle?.bundleIdentifier ?? ""
        let appName   = (bundle?.infoDictionary?["CFBundleDisplayName"] as? String)
                     ?? (bundle?.infoDictionary?["CFBundleName"] as? String)
                     ?? url.deletingPathExtension().lastPathComponent

        AppIconCache.shared.invalidate(bundleID: bundleID)

        segments[index].label = appName

        if TerminalApps.isTerminal(bundleID: bundleID) {
            // Terminal app: set appWithActions, preserve any existing runInTerminal actions
            segments[index].type    = .appWithActions
            segments[index].actions = [.launchApp(bundleID: bundleID)]
            // Existing commands (if re-picking same terminal) are cleared; user re-enters in fields
        } else {
            segments[index].actions = [.launchApp(bundleID: bundleID)]
            segments[index].type    = .actionOnly
        }
    }

    private func save() {
        let updated = Wheel(id: wheelID, hotkey: hotkey, segments: segments)

        let dir = ConfigLoader.configURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(WheelConfig(wheels: [updated])) {
            try? data.write(to: ConfigLoader.configURL)
        }

        onSave(updated)
    }
}

// ─── SegmentRow ───────────────────────────────────────────────────────────────

private struct SegmentRow: View {
    let index: Int
    @Binding var segment: Segment
    let onPickApp: () -> Void

    private var appIcon: NSImage? {
        guard case .launchApp(let id) = segment.actions.first else { return nil }
        return AppIconCache.shared.icon(forBundleID: id)
    }

    // ── Terminal helpers ──────────────────────────────────────────────────────

    /// Bundle ID of the terminal app in slot 0, or nil if not a terminal segment.
    private var terminalBundleID: String? {
        guard case .launchApp(let id) = segment.actions.first,
              TerminalApps.isTerminal(bundleID: id) else { return nil }
        return id
    }

    private var isTerminalSegment: Bool { terminalBundleID != nil }

    private var existingCommands: [String] {
        segment.actions.compactMap {
            if case .runInTerminal(let cmd, _) = $0 { return cmd }
            return nil
        }
    }

    private var command1Binding: Binding<String> {
        Binding(
            get: { existingCommands.indices.contains(0) ? existingCommands[0] : "" },
            set: { new in setCommands(cmd1: new, cmd2: existingCommands.indices.contains(1) ? existingCommands[1] : "") }
        )
    }

    private var command2Binding: Binding<String> {
        Binding(
            get: { existingCommands.indices.contains(1) ? existingCommands[1] : "" },
            set: { new in setCommands(cmd1: existingCommands.indices.contains(0) ? existingCommands[0] : "", cmd2: new) }
        )
    }

    private func setCommands(cmd1: String, cmd2: String) {
        guard let tid = terminalBundleID else { return }
        var actions: [BibloAction] = [.launchApp(bundleID: tid)]
        if !cmd1.isEmpty { actions.append(.runInTerminal(command: cmd1, terminalBundleID: tid)) }
        if !cmd2.isEmpty { actions.append(.runInTerminal(command: cmd2, terminalBundleID: tid)) }
        segment.actions     = actions
        segment.type        = actions.count > 1 ? .appWithActions : .actionOnly
        // Start on first command so it's immediately visible in the wheel
        segment.stickyIndex = actions.count > 1 ? 1 : 0
    }

    // ── Body ──────────────────────────────────────────────────────────────────

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(white: 0.35))
                    .frame(width: 16)

                Group {
                    if let img = appIcon {
                        Image(nsImage: img)
                            .resizable()
                            .interpolation(.high)
                    } else {
                        Image(systemName: segment.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(Color(red: 0.6, green: 0.55, blue: 1.0))
                    }
                }
                .frame(width: 32, height: 32)

                TextField("Label", text: $segment.label)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if case .launchApp(let id) = segment.actions.first {
                    Text(id)
                        .font(.system(size: 10))
                        .foregroundStyle(Color(white: 0.3))
                        .lineLimit(1)
                        .frame(maxWidth: 160, alignment: .trailing)
                }

                Button("Pick App") { onPickApp() }
                    .buttonStyle(GhostButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            // Terminal command fields — shown only for known terminal apps
            if isTerminalSegment {
                VStack(spacing: 6) {
                    TerminalCommandField(placeholder: "Command 1  (e.g. pwd)", text: command1Binding)
                    TerminalCommandField(placeholder: "Command 2  (e.g. git status)", text: command2Binding)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
        }
        .background(Color(red: 0.06, green: 0.06, blue: 0.09))
    }
}

// ─── TerminalCommandField ─────────────────────────────────────────────────────

private struct TerminalCommandField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(red: 0.6, green: 0.55, blue: 1.0))
                .frame(width: 16)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color(white: 0.78))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(white: 0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(white: 0.12), lineWidth: 1)
        )
    }
}

// ─── Button styles ────────────────────────────────────────────────────────────

private struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.42, green: 0.34, blue: 0.97)
                        .opacity(configuration.isPressed ? 0.7 : 1))
            )
    }
}

private struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11))
            .foregroundStyle(Color(white: configuration.isPressed ? 0.6 : 0.45))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(white: 0.2), lineWidth: 1)
            )
    }
}
