import SwiftUI

// Every glyph in this app is drawn here. No SF Symbols, no emoji, no bitmaps.

struct CBIconCairn: View {
    var size: CGFloat = 24
    var color: Color = CBTheme.slate
    var body: some View {
        Canvas { ctx, s in
            let w = s.width, h = s.height
            func stone(_ cx: CGFloat, _ cy: CGFloat, _ rw: CGFloat, _ rh: CGFloat) {
                let r = CGRect(x: cx - rw / 2, y: cy - rh / 2, width: rw, height: rh)
                ctx.fill(Path(roundedRect: r, cornerSize: CGSize(width: rh * 0.5, height: rh * 0.5)), with: .color(color))
            }
            stone(w * 0.5, h * 0.85, w * 0.80, h * 0.19)
            stone(w * 0.47, h * 0.63, w * 0.60, h * 0.17)
            stone(w * 0.53, h * 0.43, w * 0.46, h * 0.16)
            stone(w * 0.48, h * 0.24, w * 0.32, h * 0.14)
            stone(w * 0.51, h * 0.10, w * 0.20, h * 0.11)
        }
        .frame(width: size, height: size)
    }
}

struct CBIconGallery: View {
    var size: CGFloat = 24
    var color: Color = CBTheme.slate
    var body: some View {
        Canvas { ctx, s in
            let w = s.width, h = s.height
            let gap: CGFloat = w * 0.10
            let cw = (w - gap) / 2, ch = (h - gap) / 2
            for i in 0..<4 {
                let col = CGFloat(i % 2), row = CGFloat(i / 2)
                let r = CGRect(x: col * (cw + gap), y: row * (ch + gap), width: cw, height: ch)
                var p = Path(roundedRect: r, cornerRadius: 2.2)
                ctx.stroke(p, with: .color(color), lineWidth: 1.4)
                p = Path(ellipseIn: CGRect(x: r.midX - cw * 0.22, y: r.midY - ch * 0.08,
                                           width: cw * 0.44, height: ch * 0.26))
                ctx.fill(p, with: .color(color.opacity(0.75)))
            }
        }
        .frame(width: size, height: size)
    }
}

struct CBIconStone: View {
    var size: CGFloat = 24
    var color: Color = CBTheme.slate
    var body: some View {
        Canvas { ctx, s in
            let w = s.width, h = s.height
            var p = Path()
            let pts: [CGPoint] = [
                CGPoint(x: 0.94, y: 0.52), CGPoint(x: 0.80, y: 0.78), CGPoint(x: 0.52, y: 0.92),
                CGPoint(x: 0.22, y: 0.84), CGPoint(x: 0.06, y: 0.58), CGPoint(x: 0.12, y: 0.30),
                CGPoint(x: 0.38, y: 0.10), CGPoint(x: 0.70, y: 0.14), CGPoint(x: 0.90, y: 0.32)
            ]
            for (i, q) in pts.enumerated() {
                let pt = CGPoint(x: q.x * w, y: q.y * h)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
            ctx.fill(p, with: .color(color))
            var band = Path()
            band.move(to: CGPoint(x: w * 0.16, y: h * 0.46))
            band.addQuadCurve(to: CGPoint(x: w * 0.88, y: h * 0.38),
                              control: CGPoint(x: w * 0.52, y: h * 0.60))
            ctx.stroke(band, with: .color(CBTheme.paper.opacity(0.55)), lineWidth: max(1, w * 0.06))
        }
        .frame(width: size, height: size)
    }
}

struct CBIconSliders: View {
    var size: CGFloat = 24
    var color: Color = CBTheme.slate
    var body: some View {
        Canvas { ctx, s in
            let w = s.width, h = s.height
            let rows: [CGFloat] = [0.24, 0.5, 0.76]
            let knobs: [CGFloat] = [0.66, 0.34, 0.56]
            for (i, y) in rows.enumerated() {
                var line = Path()
                line.move(to: CGPoint(x: w * 0.08, y: h * y))
                line.addLine(to: CGPoint(x: w * 0.92, y: h * y))
                ctx.stroke(line, with: .color(color.opacity(0.55)), lineWidth: 1.4)
                let kx = w * knobs[i]
                let r = CGRect(x: kx - w * 0.09, y: h * y - w * 0.09, width: w * 0.18, height: w * 0.18)
                ctx.fill(Path(ellipseIn: r), with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}

struct CBIconStar: View {
    var size: CGFloat = 14
    var filled: Bool = true
    var color: Color = CBTheme.driftwood
    var body: some View {
        Canvas { ctx, s in
            let w = s.width, h = s.height
            let cx = w / 2, cy = h / 2
            let outer = min(w, h) / 2 - 0.6
            let inner = outer * 0.45
            var p = Path()
            for i in 0..<10 {
                let a = -Double.pi / 2 + Double(i) * Double.pi / 5
                let r = (i % 2 == 0) ? outer : inner
                let pt = CGPoint(x: cx + CGFloat(cos(a)) * r, y: cy + CGFloat(sin(a)) * r)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
            if filled {
                ctx.fill(p, with: .color(color))
            } else {
                ctx.stroke(p, with: .color(color.opacity(0.45)), lineWidth: 1.1)
            }
        }
        .frame(width: size, height: size)
    }
}

struct CBIconLock: View {
    var size: CGFloat = 16
    var color: Color = CBTheme.inkFaint
    var body: some View {
        Canvas { ctx, s in
            let w = s.width, h = s.height
            var shackle = Path()
            shackle.addArc(center: CGPoint(x: w * 0.5, y: h * 0.42),
                           radius: w * 0.24, startAngle: .degrees(180), endAngle: .degrees(0),
                           clockwise: false)
            ctx.stroke(shackle, with: .color(color), lineWidth: max(1.2, w * 0.11))
            let body = CGRect(x: w * 0.20, y: h * 0.42, width: w * 0.60, height: h * 0.44)
            ctx.fill(Path(roundedRect: body, cornerRadius: w * 0.10), with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

struct CBIconChevron: View {
    var size: CGFloat = 14
    var color: Color = CBTheme.inkFaint
    var pointsLeft: Bool = false
    var body: some View {
        Canvas { ctx, s in
            let w = s.width, h = s.height
            var p = Path()
            if pointsLeft {
                p.move(to: CGPoint(x: w * 0.66, y: h * 0.16))
                p.addLine(to: CGPoint(x: w * 0.30, y: h * 0.5))
                p.addLine(to: CGPoint(x: w * 0.66, y: h * 0.84))
            } else {
                p.move(to: CGPoint(x: w * 0.34, y: h * 0.16))
                p.addLine(to: CGPoint(x: w * 0.70, y: h * 0.5))
                p.addLine(to: CGPoint(x: w * 0.34, y: h * 0.84))
            }
            ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: max(1.3, w * 0.11),
                                                                 lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

struct CBIconClose: View {
    var size: CGFloat = 16
    var color: Color = CBTheme.inkSoft
    var body: some View {
        Canvas { ctx, s in
            let w = s.width, h = s.height
            var p = Path()
            p.move(to: CGPoint(x: w * 0.22, y: h * 0.22)); p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.78))
            p.move(to: CGPoint(x: w * 0.78, y: h * 0.22)); p.addLine(to: CGPoint(x: w * 0.22, y: h * 0.78))
            ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: max(1.4, w * 0.11), lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

struct CBIconCheck: View {
    var size: CGFloat = 16
    var color: Color = CBTheme.moss
    var body: some View {
        Canvas { ctx, s in
            let w = s.width, h = s.height
            var p = Path()
            p.move(to: CGPoint(x: w * 0.18, y: h * 0.52))
            p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.76))
            p.addLine(to: CGPoint(x: w * 0.84, y: h * 0.24))
            ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: max(1.6, w * 0.13),
                                                                 lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

struct CBIconTrash: View {
    var size: CGFloat = 16
    var color: Color = CBTheme.rust
    var body: some View {
        Canvas { ctx, s in
            let w = s.width, h = s.height
            var lid = Path()
            lid.move(to: CGPoint(x: w * 0.12, y: h * 0.26))
            lid.addLine(to: CGPoint(x: w * 0.88, y: h * 0.26))
            ctx.stroke(lid, with: .color(color), lineWidth: max(1.3, w * 0.10))
            var handle = Path()
            handle.move(to: CGPoint(x: w * 0.38, y: h * 0.26))
            handle.addLine(to: CGPoint(x: w * 0.40, y: h * 0.13))
            handle.addLine(to: CGPoint(x: w * 0.60, y: h * 0.13))
            handle.addLine(to: CGPoint(x: w * 0.62, y: h * 0.26))
            ctx.stroke(handle, with: .color(color), lineWidth: max(1.2, w * 0.09))
            var can = Path()
            can.move(to: CGPoint(x: w * 0.22, y: h * 0.32))
            can.addLine(to: CGPoint(x: w * 0.30, y: h * 0.88))
            can.addLine(to: CGPoint(x: w * 0.70, y: h * 0.88))
            can.addLine(to: CGPoint(x: w * 0.78, y: h * 0.32))
            ctx.stroke(can, with: .color(color), style: StrokeStyle(lineWidth: max(1.2, w * 0.09), lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

struct CBIconStep: View {
    var size: CGFloat = 18
    var color: Color = CBTheme.slate
    var plus: Bool = true
    var body: some View {
        Canvas { ctx, s in
            let w = s.width, h = s.height
            var p = Path()
            p.move(to: CGPoint(x: w * 0.20, y: h * 0.5)); p.addLine(to: CGPoint(x: w * 0.80, y: h * 0.5))
            if plus {
                p.move(to: CGPoint(x: w * 0.5, y: h * 0.20)); p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.80))
            }
            ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: max(1.6, w * 0.11), lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

/// The twist glyph inside the rotation ring.
struct CBIconTwist: View {
    var size: CGFloat = 26
    var color: Color = CBTheme.slate
    var body: some View {
        Canvas { ctx, s in
            let w = s.width, h = s.height
            let c = CGPoint(x: w / 2, y: h / 2)
            let r = min(w, h) * 0.32
            var arc = Path()
            arc.addArc(center: c, radius: r, startAngle: .degrees(-40), endAngle: .degrees(215), clockwise: false)
            ctx.stroke(arc, with: .color(color), style: StrokeStyle(lineWidth: max(1.4, w * 0.08), lineCap: .round))
            var head = Path()
            let a = -40.0 * Double.pi / 180
            let tip = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
            head.move(to: CGPoint(x: tip.x - w * 0.02, y: tip.y - h * 0.16))
            head.addLine(to: CGPoint(x: tip.x + w * 0.12, y: tip.y + h * 0.02))
            head.addLine(to: CGPoint(x: tip.x - w * 0.08, y: tip.y + h * 0.10))
            head.closeSubpath()
            ctx.fill(head, with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

/// A small plumb-bob mark used in onboarding and legends.
struct CBIconPlumb: View {
    var size: CGFloat = 18
    var color: Color = CBTheme.seaglass
    var body: some View {
        Canvas { ctx, s in
            let w = s.width, h = s.height
            var line = Path()
            line.move(to: CGPoint(x: w * 0.5, y: 0))
            line.addLine(to: CGPoint(x: w * 0.5, y: h * 0.62))
            ctx.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 1.4, dash: [3, 2.4]))
            var bob = Path()
            bob.move(to: CGPoint(x: w * 0.5, y: h))
            bob.addLine(to: CGPoint(x: w * 0.32, y: h * 0.66))
            bob.addLine(to: CGPoint(x: w * 0.68, y: h * 0.66))
            bob.closeSubpath()
            ctx.fill(bob, with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

/// Wind streak glyph for the Windward gauge.
struct CBIconWind: View {
    var size: CGFloat = 20
    var color: Color = CBTheme.seaglass
    var body: some View {
        Canvas { ctx, s in
            let w = s.width, h = s.height
            let ys: [CGFloat] = [0.28, 0.5, 0.72]
            let lens: [CGFloat] = [0.72, 0.92, 0.58]
            for (i, y) in ys.enumerated() {
                var p = Path()
                p.move(to: CGPoint(x: w * 0.06, y: h * y))
                p.addLine(to: CGPoint(x: w * lens[i], y: h * y))
                ctx.stroke(p, with: .color(color.opacity(0.55 + Double(i) * 0.14)),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Star row

struct CBStarRow: View {
    let earned: Int
    var size: CGFloat = 12
    var color: Color = CBTheme.driftwood
    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<3, id: \.self) { i in
                CBIconStar(size: size, filled: i < earned, color: color)
            }
        }
    }
}
