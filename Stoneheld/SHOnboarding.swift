import SwiftUI

struct SHOnboardingView: View {
    @ObservedObject var store = SHStore.shared
    @State private var page = 0

    private let titles = ["Drag to place", "Twist to seat", "Keep the plumb over the seat"]
    private let bodies = [
        "Slide the stone left and right across the shore. The dashed outline below shows exactly where it will land — it falls straight down, so nothing is hidden from you.",
        "Turn the twist ring, or pinch with two fingers, to rotate in one degree steps. On release the stone tips about its first contact until a second point lands, and that is your seat.",
        "The app adds up the mass of everything above each contact and drops a plumb line from the combined centre. While that line stays inside the highlighted seat, the cairn holds. Once it leaves, torque wins."
    ]

    var body: some View {
        ZStack {
            SHBackground()
            VStack(spacing: 0) {
                HStack {
                    Text("Stoneheld")
                        .font(SHTheme.displayBold(19))
                        .foregroundColor(SHTheme.ink)
                    Spacer()
                    Button(action: finish) {
                        Text("Skip")
                            .font(SHTheme.label(13, .semibold))
                            .foregroundColor(SHTheme.inkSoft)
                            .padding(.vertical, 6).padding(.horizontal, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, SHSafe.top + 8)

                Spacer(minLength: 8)

                card
                    .padding(.horizontal, 22)

                Spacer(minLength: 8)

                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? SHTheme.slate : SHTheme.inkFaint.opacity(0.4))
                            .frame(width: i == page ? 20 : 7, height: 7)
                    }
                }
                .padding(.bottom, 14)

                HStack(spacing: 10) {
                    if page > 0 {
                        SHGhostButton(title: "Back") { page -= 1 }
                    }
                    SHWideButton(title: page == 2 ? "Start Stacking" : "Next") {
                        if page == 2 { finish() } else { page += 1 }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, max(20, SHSafe.bottom + 12))
            }
            SHStatusStrip()
        }
    }

    private var card: some View {
        VStack(spacing: 14) {
            SHOnboardingArt(page: page)
                .frame(height: SHSafe.isShort ? 180 : 230)
            Text(titles[page])
                .font(SHTheme.displayBold(20))
                .foregroundColor(SHTheme.ink)
                .multilineTextAlignment(.center)
            Text(bodies[page])
                .font(SHTheme.label(12.5, .regular))
                .foregroundColor(SHTheme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cbCard(pad: 18, radius: 16)
    }

    private func finish() {
        store.mutate { $0.onboardingDone = true }
    }
}

struct SHOnboardingArt: View {
    let page: Int

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            Canvas { ctx, _ in
                var c = ctx
                switch page {
                case 0: drawDrag(&c, size: size)
                case 1: drawTwist(&c, size: size)
                default: drawPlumb(&c, size: size)
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }

    private func stackMap(_ size: CGSize, worldCenter: CGPoint, scale: CGFloat) -> (CGPoint) -> CGPoint {
        { w in
            CGPoint(x: size.width / 2 + (w.x - worldCenter.x) * scale,
                    y: size.height * 0.82 - (w.y - worldCenter.y) * scale)
        }
    }

    // Page 1 — a stone sliding above a small cairn
    private func drawDrag(_ ctx: inout GraphicsContext, size: CGSize) {
        let scale: CGFloat = 0.72
        let map = stackMap(size, worldCenter: CGPoint(x: 0, y: 0), scale: scale)
        SHRender.drawBase(&ctx, map: { l in map(CGPoint(x: l.x * 0.7, y: l.y)) }, scale: scale)

        drawSeated(&ctx, id: 10, at: CGPoint(x: 0, y: 18), rot: 0, map: map, scale: scale)
        drawSeated(&ctx, id: 4, at: CGPoint(x: 4, y: 44), rot: 0.08, map: map, scale: scale)

        // hovering stone
        drawSeated(&ctx, id: 20, at: CGPoint(x: 26, y: 118), rot: -0.06, map: map, scale: scale)
        // ghost landing outline
        let k = SHCatalog.kind(20)
        let ghost = SHRender.path(k, map: { l in
            map(CGPoint(x: 26 + l.x * cos(-0.06) - l.y * sin(-0.06),
                        y: 70 + l.x * sin(-0.06) + l.y * cos(-0.06)))
        })
        ctx.stroke(ghost, with: .color(SHTheme.slate.opacity(0.5)),
                   style: StrokeStyle(lineWidth: 1.3, dash: [5, 4]))

        // drag arrow
        let y = size.height * 0.20
        var arrow = Path()
        arrow.move(to: CGPoint(x: size.width * 0.24, y: y))
        arrow.addLine(to: CGPoint(x: size.width * 0.76, y: y))
        ctx.stroke(arrow, with: .color(SHTheme.seaglass),
                   style: StrokeStyle(lineWidth: 2, lineCap: .round))
        for (x, dir) in [(size.width * 0.24, CGFloat(1)), (size.width * 0.76, CGFloat(-1))] {
            var head = Path()
            head.move(to: CGPoint(x: x, y: y))
            head.addLine(to: CGPoint(x: x + 9 * dir, y: y - 6))
            head.addLine(to: CGPoint(x: x + 9 * dir, y: y + 6))
            head.closeSubpath()
            ctx.fill(head, with: .color(SHTheme.seaglass))
        }
    }

    // Page 2 — the twist ring and a rotating stone
    private func drawTwist(_ ctx: inout GraphicsContext, size: CGSize) {
        let scale: CGFloat = 0.8
        let map = stackMap(size, worldCenter: CGPoint(x: 0, y: 30), scale: scale)
        SHRender.drawBase(&ctx, map: { l in map(CGPoint(x: l.x * 0.6, y: l.y)) }, scale: scale)
        drawSeated(&ctx, id: 9, at: CGPoint(x: 0, y: 18), rot: 0, map: map, scale: scale)

        // ghosts of intermediate rotations
        let k = SHCatalog.kind(28)
        for (i, r) in [(-0.55), (-0.28)].enumerated() {
            let p = SHRender.path(k, map: { l in
                map(CGPoint(x: 6 + l.x * cos(r) - l.y * sin(r),
                            y: 76 + l.x * sin(r) + l.y * cos(r)))
            })
            ctx.stroke(p, with: .color(SHTheme.inkFaint.opacity(0.35 + Double(i) * 0.18)),
                       style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
        }
        drawSeated(&ctx, id: 28, at: CGPoint(x: 6, y: 76), rot: 0, map: map, scale: scale)

        // ring
        let c = CGPoint(x: size.width * 0.80, y: size.height * 0.28)
        let r: CGFloat = min(size.width, size.height) * 0.15
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                   with: .color(SHTheme.cardEdge), lineWidth: 2)
        for i in 0..<12 {
            let a = Double(i) / 12 * 2 * Double.pi
            var tick = Path()
            tick.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * (r - 5), y: c.y + CGFloat(sin(a)) * (r - 5)))
            tick.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r))
            ctx.stroke(tick, with: .color(SHTheme.inkFaint), lineWidth: 1.2)
        }
        var needle = Path()
        needle.move(to: c)
        needle.addLine(to: CGPoint(x: c.x + CGFloat(cos(-2.1)) * (r - 3), y: c.y + CGFloat(sin(-2.1)) * (r - 3)))
        ctx.stroke(needle, with: .color(SHTheme.seaglass), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        var sweep = Path()
        sweep.addArc(center: c, radius: r + 8, startAngle: .degrees(-120), endAngle: .degrees(-40), clockwise: false)
        ctx.stroke(sweep, with: .color(SHTheme.seaglass.opacity(0.6)),
                   style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 3]))
    }

    // Page 3 — the plumb line inside and outside the seat
    private func drawPlumb(_ ctx: inout GraphicsContext, size: CGSize) {
        let scale: CGFloat = 0.62
        let leftMap: (CGPoint) -> CGPoint = { w in
            CGPoint(x: size.width * 0.27 + w.x * scale, y: size.height * 0.84 - w.y * scale)
        }
        let rightMap: (CGPoint) -> CGPoint = { w in
            CGPoint(x: size.width * 0.73 + w.x * scale, y: size.height * 0.84 - w.y * scale)
        }

        func scene(_ map: @escaping (CGPoint) -> CGPoint, offset: Double, good: Bool) {
            SHRender.drawBase(&ctx, map: { l in map(CGPoint(x: l.x * 0.45, y: l.y)) }, scale: scale)
            drawSeated(&ctx, id: 10, at: CGPoint(x: 0, y: 16), rot: 0, map: map, scale: scale)
            drawSeated(&ctx, id: 5, at: CGPoint(x: offset * 0.5, y: 44), rot: 0.05, map: map, scale: scale)
            drawSeated(&ctx, id: 22, at: CGPoint(x: offset, y: 78), rot: -0.08, map: map, scale: scale)

            let seatY = 30.0
            let xL = -22.0, xR = 22.0
            var seat = Path()
            seat.move(to: map(CGPoint(x: xL, y: seatY)))
            seat.addLine(to: map(CGPoint(x: xR, y: seatY)))
            ctx.stroke(seat, with: .color(SHTheme.seaglass), style: StrokeStyle(lineWidth: 4, lineCap: .round))

            let comX = offset * 0.75
            let col = good ? SHTheme.moss : SHTheme.rust
            var plumb = Path()
            plumb.move(to: map(CGPoint(x: comX, y: 96)))
            plumb.addLine(to: map(CGPoint(x: comX, y: seatY - 4)))
            ctx.stroke(plumb, with: .color(col), style: StrokeStyle(lineWidth: 1.8, dash: [5, 4]))
            let top = map(CGPoint(x: comX, y: 96))
            ctx.fill(Path(ellipseIn: CGRect(x: top.x - 5, y: top.y - 5, width: 10, height: 10)),
                     with: .color(col))
        }

        scene(leftMap, offset: 4, good: true)
        scene(rightMap, offset: 34, good: false)

        let a = Text("holds").font(SHTheme.label(11, .semibold)).foregroundColor(SHTheme.moss)
        ctx.draw(a, at: CGPoint(x: size.width * 0.27, y: size.height * 0.95))
        let b = Text("goes").font(SHTheme.label(11, .semibold)).foregroundColor(SHTheme.rust)
        ctx.draw(b, at: CGPoint(x: size.width * 0.73, y: size.height * 0.95))
    }

    private func drawSeated(_ ctx: inout GraphicsContext, id: Int, at p: CGPoint, rot: Double,
                            map: @escaping (CGPoint) -> CGPoint, scale: CGFloat) {
        let k = SHCatalog.kind(id)
        let c = cos(rot), s = sin(rot)
        SHRender.drawStone(&ctx, kind: k, map: { l in
            map(CGPoint(x: Double(p.x) + Double(l.x) * c - Double(l.y) * s,
                        y: Double(p.y) + Double(l.x) * s + Double(l.y) * c))
        }, scale: scale)
    }
}
