import SwiftUI

struct WheelView: View {
    @ObservedObject var state: WheelState

    // ── Geometry constants ────────────────────────────────────────────────────
    private let outerRadius:    CGFloat = 160
    private let innerRadius:    CGFloat = 44
    private let labelRadius:    CGFloat = 112
    private let outerRingInner: CGFloat = 178
    private let outerRingOuter: CGFloat = 268
    private let outerLabelR:    CGFloat = 223
    private let accentColor = Color(red: 0.42, green: 0.34, blue: 0.97)
    private let segGap: CGFloat = 0.024

    var body: some View {
        GeometryReader { _ in
            let origin   = state.wheelOrigin
            let segCount = state.wheel?.segments.count ?? 8

            ZStack {
                // ── Segments + outer arcs (Canvas) ────────────────────────────
                WheelCanvas(
                    state: state,
                    origin: origin,
                    innerRadius: innerRadius,
                    outerRadius: outerRadius,
                    outerRingInner: outerRingInner,
                    outerRingOuter: outerRingOuter,
                    accentColor: accentColor,
                    segGap: segGap
                )

                // ── Center "Cancel" label ─────────────────────────────────────
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
                }

                // ── Primary segment labels ────────────────────────────────────
                if let wheel = state.wheel {
                    ForEach(0 ..< wheel.segments.count, id: \.self) { i in
                        let seg         = wheel.segments[i]
                        let highlighted = state.highlightedIndex == i
                        let mid = midAngle(i: i, n: segCount)
                        let lx  = origin.x + labelRadius * CGFloat(cos(mid))
                        let ly  = origin.y + labelRadius * CGFloat(sin(mid))

                        VStack(spacing: 3) {
                            SegmentIconView(segment: seg, highlighted: highlighted)
                            Text(seg.label)
                                .font(.system(size: 11, weight: highlighted ? .semibold : .regular))
                                .foregroundStyle(highlighted ? Color.white : Color.white.opacity(0.38))
                                .fixedSize()
                        }
                        .position(x: lx, y: ly)
                        .animation(.easeOut(duration: 0.08), value: highlighted)
                    }
                }

                // ── Outer ring command labels ─────────────────────────────────
                if let wheel = state.wheel, let innerIdx = state.highlightedIndex {
                    OuterRingLabels(
                        commands: terminalCommands(in: wheel.segments[innerIdx]),
                        segIdx: innerIdx,
                        segCount: segCount,
                        origin: origin,
                        labelRadius: outerLabelR,
                        segGap: Double(segGap),
                        selectedIndex: state.outerSelectedIndex
                    )
                }
            }
        }
        .ignoresSafeArea()
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private func terminalCommands(in seg: Segment) -> [String] {
        seg.actions.compactMap {
            if case .runInTerminal(let cmd, _) = $0 { return cmd }
            return nil
        }
    }

    private func midAngle(i: Int, n: Int) -> Double {
        2 * Double.pi / Double(n) * Double(i) - Double.pi / 2
    }
}

// ─── Canvas draws all arc geometry ────────────────────────────────────────────

private struct WheelCanvas: View {
    @ObservedObject var state: WheelState
    let origin:        CGPoint
    let innerRadius:   CGFloat
    let outerRadius:   CGFloat
    let outerRingInner: CGFloat
    let outerRingOuter: CGFloat
    let accentColor:   Color
    let segGap:        CGFloat

    var body: some View {
        Canvas { ctx, _ in
            guard let wheel = state.wheel else { return }
            let n = wheel.segments.count

            // Primary segments
            for i in 0 ..< n {
                let (s, e) = segAngles(i: i, n: n)
                let highlighted = state.highlightedIndex == i
                let path = annularSector(center: origin, inner: innerRadius, outer: outerRadius,
                                         start: s + segGap, end: e - segGap)
                ctx.fill(path, with: .color(highlighted ? accentColor.opacity(0.52) : Color.white.opacity(0.06)))
                ctx.stroke(path, with: .color(Color.white.opacity(highlighted ? 0.28 : 0.08)), lineWidth: 1)
            }

            // Dead-zone
            let cs = state.highlightedIndex == nil
            let dz = Path(ellipseIn: CGRect(x: origin.x - innerRadius, y: origin.y - innerRadius,
                                            width: innerRadius * 2, height: innerRadius * 2))
            ctx.fill(dz, with: .color(cs ? accentColor.opacity(0.45) : Color.white.opacity(0.035)))
            ctx.stroke(dz, with: .color(cs ? accentColor.opacity(0.8) : Color.white.opacity(0.07)),
                       lineWidth: cs ? 1.5 : 1)

            // Centre dot
            let r: CGFloat = 3
            let dot = Path(ellipseIn: CGRect(x: origin.x - r, y: origin.y - r, width: r * 2, height: r * 2))
            ctx.fill(dot, with: .color(cs ? Color.white : accentColor))

            // Outer ring arcs (only when a terminal segment is highlighted)
            guard let idx = state.highlightedIndex else { return }
            let subCount = wheel.segments[idx].actions.filter {
                if case .runInTerminal = $0 { return true }; return false
            }.count
            guard subCount > 0 else { return }

            let (ss, se) = segAngles(i: idx, n: n)
            let span = (se - ss - Double(segGap) * 2) / Double(subCount)

            for j in 0 ..< subCount {
                let s2 = ss + Double(segGap) + Double(j) * span
                let e2 = s2 + span - Double(segGap) * 0.5
                let sel = state.outerSelectedIndex == j
                let path = annularSector(center: origin, inner: outerRingInner, outer: outerRingOuter,
                                         start: s2, end: e2)
                ctx.fill(path, with: .color(sel ? accentColor.opacity(0.60) : Color.white.opacity(0.07)))
                ctx.stroke(path, with: .color(Color.white.opacity(sel ? 0.30 : 0.10)), lineWidth: 1)
            }
        }
    }

    private func segAngles(i: Int, n: Int) -> (Double, Double) {
        let seg = 2 * Double.pi / Double(n)
        let mid = -Double.pi / 2 + Double(i) * seg
        return (mid - seg / 2, mid + seg / 2)
    }

    private func annularSector(center: CGPoint, inner: CGFloat, outer: CGFloat,
                                start: Double, end: Double) -> Path {
        var p = Path()
        p.addArc(center: center, radius: outer, startAngle: .radians(start),
                 endAngle: .radians(end), clockwise: false)
        p.addArc(center: center, radius: inner, startAngle: .radians(end),
                 endAngle: .radians(start), clockwise: true)
        p.closeSubpath()
        return p
    }
}

// ─── Outer ring text labels ────────────────────────────────────────────────────

private struct OuterRingLabels: View {
    let commands:     [String]
    let segIdx:       Int
    let segCount:     Int
    let origin:       CGPoint
    let labelRadius:  CGFloat
    let segGap:       Double
    let selectedIndex: Int?

    var body: some View {
        let count = commands.count
        guard count > 0 else { return AnyView(EmptyView()) }

        let seg  = 2 * Double.pi / Double(segCount)
        let mid  = -Double.pi / 2 + Double(segIdx) * seg
        let s    = mid - seg / 2
        let span = (seg - segGap * 2) / Double(count)

        return AnyView(ZStack {
            ForEach(0 ..< count, id: \.self) { j in
                let cmd  = commands[j]
                let midA = s + segGap + Double(j) * span + span / 2
                let lx   = origin.x + labelRadius * CGFloat(cos(midA))
                let ly   = origin.y + labelRadius * CGFloat(sin(midA))
                let sel  = selectedIndex == j

                Text(cmd)
                    .font(.system(size: 11,
                                  weight: sel ? .semibold : .regular,
                                  design: .monospaced))
                    .foregroundStyle(sel ? Color.white : Color.white.opacity(0.45))
                    .lineLimit(1)
                    .frame(maxWidth: 96)
                    .position(x: lx, y: ly)
                    .animation(.easeOut(duration: 0.06), value: sel)
            }
        })
    }
}

// ─── Segment icon ─────────────────────────────────────────────────────────────

struct SegmentIconView: View {
    let segment:    Segment
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
