import SwiftUI

struct WheelView: View {
    @ObservedObject var state: WheelState

    // ── Geometry constants ────────────────────────────────────────────────────
    private let outerRadius:  CGFloat = 160
    private let innerRadius:  CGFloat = 44
    private let labelRadius:  CGFloat = 112

    // Outer command ring
    private let outerRingInner:  CGFloat = 178
    private let outerRingOuter:  CGFloat = 268
    private let outerLabelRadius: CGFloat = 223

    private let accentColor = Color(red: 0.42, green: 0.34, blue: 0.97)
    private let segGap: CGFloat = 0.024

    var body: some View {
        GeometryReader { geo in
            let origin   = state.wheelOrigin
            let segCount = state.wheel?.segments.count ?? 8

            ZStack {
                // ── Primary segments + outer ring (Canvas for perf) ───────────
                Canvas { ctx, _ in
                    guard let wheel = state.wheel else { return }

                    // Primary segments
                    for i in 0 ..< wheel.segments.count {
                        let (startA, endA) = angles(i: i, n: wheel.segments.count)
                        let highlighted = state.highlightedIndex == i

                        let path = annularSector(
                            center: origin, inner: innerRadius, outer: outerRadius,
                            start: startA + segGap, end: endA - segGap
                        )
                        ctx.fill(path, with: .color(
                            highlighted ? accentColor.opacity(0.52) : Color.white.opacity(0.06)
                        ))
                        ctx.stroke(path, with: .color(
                            Color.white.opacity(highlighted ? 0.28 : 0.08)
                        ), lineWidth: 1)
                    }

                    // Dead-zone circle
                    let centerSelected = state.highlightedIndex == nil
                    let dz = Path(ellipseIn: CGRect(
                        x: origin.x - innerRadius, y: origin.y - innerRadius,
                        width: innerRadius * 2,    height: innerRadius * 2
                    ))
                    ctx.fill(dz, with: .color(
                        centerSelected ? accentColor.opacity(0.45) : Color.white.opacity(0.035)
                    ))
                    ctx.stroke(dz, with: .color(
                        centerSelected ? accentColor.opacity(0.8) : Color.white.opacity(0.07)
                    ), lineWidth: centerSelected ? 1.5 : 1)

                    // Centre dot
                    let dotR: CGFloat = 3
                    let dot = Path(ellipseIn: CGRect(
                        x: origin.x - dotR, y: origin.y - dotR,
                        width: dotR * 2,    height: dotR * 2
                    ))
                    ctx.fill(dot, with: .color(centerSelected ? Color.white : accentColor))

                    // Outer command ring — appears when a terminal segment is highlighted
                    if let innerIdx = state.highlightedIndex {
                        let seg = wheel.segments[innerIdx]
                        let subCmds = seg.actions.indices.filter {
                            if case .runInTerminal = seg.actions[$0] { return true }
                            return false
                        }
                        guard !subCmds.isEmpty else { return }

                        let (segStart, segEnd) = angles(i: innerIdx, n: wheel.segments.count)
                        let totalSpan = segEnd - segStart - segGap * 2
                        let subSpan   = totalSpan / Double(subCmds.count)

                        for (j, _) in subCmds.enumerated() {
                            let subStart = segStart + segGap + Double(j) * subSpan
                            let subEnd   = subStart + subSpan - segGap * 0.5
                            let selected = state.outerSelectedIndex == j

                            let path = annularSector(
                                center: origin,
                                inner: outerRingInner, outer: outerRingOuter,
                                start: subStart, end: subEnd
                            )
                            ctx.fill(path, with: .color(
                                selected
                                    ? accentColor.opacity(0.60)
                                    : Color.white.opacity(0.07)
                            ))
                            ctx.stroke(path, with: .color(
                                Color.white.opacity(selected ? 0.30 : 0.10)
                            ), lineWidth: 1)
                        }
                    }
                }

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
                    .animation(.easeOut(duration: 0.08), value: state.highlightedIndex == nil)
                }

                // ── Primary segment labels ────────────────────────────────────
                if let wheel = state.wheel {
                    ForEach(Array(wheel.segments.enumerated()), id: \.offset) { i, seg in
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
                    let seg = wheel.segments[innerIdx]
                    let subCmds: [(Int, String)] = seg.actions.compactMap {
                        if case .runInTerminal(let cmd, _) = $0 { return (0, cmd) }
                        return nil
                    }.enumerated().map { ($0.offset, $0.element.1) }

                    if !subCmds.isEmpty {
                        let (segStart, segEnd) = angles(i: innerIdx, n: segCount)
                        let totalSpan = segEnd - segStart - segGap * 2
                        let subSpan   = totalSpan / Double(subCmds.count)

                        ForEach(0 ..< subCmds.count, id: \.self) { j in
                            let cmd      = subCmds[j].1
                            let midA     = segStart + segGap + Double(j) * subSpan + subSpan / 2
                            let lx       = origin.x + outerLabelRadius * CGFloat(cos(midA))
                            let ly       = origin.y + outerLabelRadius * CGFloat(sin(midA))
                            let selected = state.outerSelectedIndex == j

                            Text(cmd)
                                .font(.system(size: 11, weight: selected ? .semibold : .regular,
                                              design: .monospaced))
                                .foregroundStyle(selected ? Color.white : Color.white.opacity(0.45))
                                .lineLimit(1)
                                .frame(maxWidth: 96)
                                .position(x: lx, y: ly)
                                .animation(.easeOut(duration: 0.06), value: selected)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    // ── Geometry helpers ──────────────────────────────────────────────────────

    private func angles(i: Int, n: Int) -> (Double, Double) {
        let seg    = 2 * Double.pi / Double(n)
        let centre = -Double.pi / 2 + Double(i) * seg
        return (centre - seg / 2, centre + seg / 2)
    }

    private func midAngle(i: Int, n: Int) -> Double {
        let seg = 2 * Double.pi / Double(n)
        return -Double.pi / 2 + Double(i) * seg
    }

    private func annularSector(
        center: CGPoint, inner: CGFloat, outer: CGFloat,
        start: Double, end: Double
    ) -> Path {
        var p = Path()
        p.addArc(center: center, radius: outer,
                 startAngle: .radians(start), endAngle: .radians(end), clockwise: false)
        p.addArc(center: center, radius: inner,
                 startAngle: .radians(end), endAngle: .radians(start), clockwise: true)
        p.closeSubpath()
        return p
    }
}

// ─── Segment icon ─────────────────────────────────────────────────────────────

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
