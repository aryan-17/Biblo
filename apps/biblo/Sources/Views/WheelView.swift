import SwiftUI

struct WheelView: View {
    @ObservedObject var state: WheelState

    // ── Geometry constants ────────────────────────────────────────────────────
    private let outerRadius: CGFloat = 160
    private let innerRadius: CGFloat = 44      // dead-zone boundary
    private let labelRadius: CGFloat = 112     // distance from centre to label

    private let accentColor = Color(red: 0.42, green: 0.34, blue: 0.97)
    private let segGap: CGFloat = 0.024        // radians of gap between segments

    var body: some View {
        GeometryReader { geo in
            let origin = state.wheelOrigin
            let segCount = state.wheel?.segments.count ?? 8

            ZStack {
                // ── Segment fills + strokes (Canvas for perf) ─────────────
                Canvas { ctx, _ in
                    guard let wheel = state.wheel else { return }

                    for i in 0 ..< wheel.segments.count {
                        let (startA, endA) = angles(i: i, n: wheel.segments.count)
                        let highlighted = state.highlightedIndex == i

                        let path = annularSector(
                            center: origin,
                            inner: innerRadius,
                            outer: outerRadius,
                            start: startA + segGap,
                            end:   endA   - segGap
                        )

                        ctx.fill(path, with: .color(
                            highlighted
                                ? accentColor.opacity(0.52)
                                : Color.white.opacity(0.06)
                        ))
                        ctx.stroke(path, with: .color(
                            Color.white.opacity(highlighted ? 0.28 : 0.08)
                        ), lineWidth: 1)
                    }

                    // Dead-zone circle — highlighted when center is selected
                    let centerSelected = state.highlightedIndex == nil
                    let dz = Path(ellipseIn: CGRect(
                        x: origin.x - innerRadius, y: origin.y - innerRadius,
                        width: innerRadius * 2,    height: innerRadius * 2
                    ))
                    ctx.fill(dz, with: .color(
                        centerSelected
                            ? accentColor.opacity(0.45)
                            : Color.white.opacity(0.035)
                    ))
                    ctx.stroke(dz, with: .color(
                        centerSelected
                            ? accentColor.opacity(0.8)
                            : Color.white.opacity(0.07)
                    ), lineWidth: centerSelected ? 1.5 : 1)

                    // Centre dot
                    let dotR: CGFloat = 3
                    let dot = Path(ellipseIn: CGRect(
                        x: origin.x - dotR, y: origin.y - dotR,
                        width: dotR * 2,    height: dotR * 2
                    ))
                    ctx.fill(dot, with: .color(
                        centerSelected ? Color.white : accentColor
                    ))
                }

                // ── Center "Cancel" label (SwiftUI — only when center selected) ──
                if state.highlightedIndex == nil {
                    VStack(spacing: 2) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white)
                        Text("Cancel")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                    .position(origin)
                    .animation(.easeOut(duration: 0.08), value: state.highlightedIndex == nil)
                }

                // ── Labels (SwiftUI for SF Symbols + text) ────────────────
                if let wheel = state.wheel {
                    ForEach(Array(wheel.segments.enumerated()), id: \.offset) { i, seg in
                        let highlighted = state.highlightedIndex == i
                        let mid = midAngle(i: i, n: segCount)
                        let lx  = origin.x + labelRadius * CGFloat(cos(mid))
                        let ly  = origin.y + labelRadius * CGFloat(sin(mid))
                        let actionIdx = min(
                            state.actionIndices[i] ?? seg.stickyIndex,
                            max(0, seg.actions.count - 1)
                        )

                        VStack(spacing: 3) {
                            SegmentIconView(segment: seg, highlighted: highlighted)

                            Text(seg.label)
                                .font(.system(size: 11, weight: highlighted ? .semibold : .regular))
                                .foregroundStyle(highlighted ? Color.white : Color.white.opacity(0.38))
                                .fixedSize()

                            // Sub-label for level-2 segments
                            if seg.actions.count > 1 {
                                Text(seg.actions[actionIdx].displayLabel)
                                    .font(.system(size: 9))
                                    .foregroundStyle(
                                        highlighted
                                            ? Color(red: 0.7, green: 0.65, blue: 1.0).opacity(0.9)
                                            : Color.white.opacity(0.2)
                                    )
                                    .lineLimit(1)
                                    .frame(maxWidth: 72)
                            }
                        }
                        .position(x: lx, y: ly)
                        .animation(.easeOut(duration: 0.08), value: highlighted)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    // ── Geometry helpers ──────────────────────────────────────────────────────

    /// Returns (startAngle, endAngle) in SwiftUI radians for segment i of n,
    /// centred at top (12 o'clock), going clockwise.
    ///   angle 0 = right (3 o'clock), −π/2 = top (12 o'clock)
    private func angles(i: Int, n: Int) -> (Double, Double) {
        let seg = 2 * Double.pi / Double(n)
        let centre = -Double.pi / 2 + Double(i) * seg
        return (centre - seg / 2, centre + seg / 2)
    }

    /// Midpoint angle for label placement.
    private func midAngle(i: Int, n: Int) -> Double {
        let seg = 2 * Double.pi / Double(n)
        return -Double.pi / 2 + Double(i) * seg
    }

    /// Annular sector path (donut slice).
    /// clockwise: false = clockwise on screen (SwiftUI y-down convention).
    private func annularSector(
        center: CGPoint,
        inner: CGFloat, outer: CGFloat,
        start: Double, end: Double
    ) -> Path {
        var p = Path()
        p.addArc(center: center, radius: outer,
                 startAngle: .radians(start), endAngle: .radians(end), clockwise: false)
        p.addArc(center: center, radius: inner,
                 startAngle: .radians(end),   endAngle: .radians(start), clockwise: true)
        p.closeSubpath()
        return p
    }
}

// ─── Segment icon: app icon if launchApp, otherwise SF Symbol ─────────────────

struct SegmentIconView: View {
    let segment: Segment
    let highlighted: Bool

    private var appIcon: NSImage? {
        guard case .launchApp(let id) = segment.actions.first else { return nil }
        return AppIconCache.shared.icon(forBundleID: id)
    }

    var body: some View {
        if let img = appIcon {
            Image(nsImage: img)
                .resizable()
                .interpolation(.high)
                .frame(width: 26, height: 26)
                .opacity(highlighted ? 1.0 : 0.55)
        } else {
            Image(systemName: segment.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(highlighted ? Color.white : Color.white.opacity(0.45))
        }
    }
}
