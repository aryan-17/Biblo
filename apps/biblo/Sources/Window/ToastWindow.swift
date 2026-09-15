import AppKit
import SwiftUI

/// Floating auto-dismiss confirmation shown after captureOutput succeeds.
final class ToastWindow: NSPanel {

    init() {
        super.init(
            contentRect: CGRect(x: 0, y: 0, width: 300, height: 48),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        ignoresMouseEvents = true
    }

    /// Show `message` centred near the top of `screen` for 1.5 seconds.
    func show(message: String, on screen: NSScreen? = NSScreen.main) {
        let width: CGFloat  = 300
        let height: CGFloat = 48
        let hosting = NSHostingView(rootView: ToastView(message: message))
        hosting.frame = CGRect(x: 0, y: 0, width: width, height: height)
        contentView = hosting

        let target = screen ?? NSScreen.main ?? NSScreen.screens[0]
        let x = target.frame.midX - width / 2
        let y = target.frame.maxY - 80
        setFrame(CGRect(x: x, y: y, width: width, height: height), display: true)

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(dismiss), object: nil)
        orderFront(nil)
        perform(#selector(dismiss), with: nil, afterDelay: 1.5)
    }

    @objc private func dismiss() {
        orderOut(nil)
    }
}

// ── Toast view ────────────────────────────────────────────────────────────────

private struct ToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 15))
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
