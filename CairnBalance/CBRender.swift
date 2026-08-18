import SwiftUI

// MARK: - Stone rendering
//
// One routine draws every stone everywhere: the play board, the gallery
// thumbnails, the collection browser. Textures are stroked in the stone's own
// local frame so they rotate with it.

enum CBRender {

    /// Builds a screen-space path from a stone's local outline.
    static func path(_ kind: CBStoneKind, map: (CGPoint) -> CGPoint) -> Path {
        var p = Path()
        let pts = kind.poly.points
        guard pts.count >= 3 else { return p }
        p.move(to: map(pts[0]))
        for i in 1..<pts.count { p.addLine(to: map(pts[i])) }
        p.closeSubpath()
        return p
    }

    static func drawStone(_ ctx: inout GraphicsContext,
                          kind: CBStoneKind,
                          map: (CGPoint) -> CGPoint,
                          scale: CGFloat,
                          opacity: Double = 1.0,
                          ghost: Bool = false,
                          outline: Color? = nil) {

        let body = path(kind, map: map)
        let tint = CBTheme.stoneTints[min(max(0, kind.tint), CBTheme.stoneTints.count - 1)]

        if ghost {
            ctx.stroke(body, with: .color(tint.opacity(0.55 * opacity)),
                       style: StrokeStyle(lineWidth: max(1, 1.3 * scale), dash: [5 * scale, 4 * scale]))
            return
        }

        ctx.fill(body, with: .color(tint.opacity(opacity)))

        // Texture, clipped to the silhouette.
        var sub = ctx
        sub.clip(to: body)
        drawTexture(&sub, kind: kind, map: map, scale: scale, opacity: opacity)

        // Soft top light + bottom shade, drawn in local space so they roll with it.
        let b = kind.poly
        var lit = Path()
        lit.move(to: map(CGPoint(x: b.minX, y: b.maxY * 0.30)))
        lit.addQuadCurve(to: map(CGPoint(x: b.maxX, y: b.maxY * 0.22)),
                         control: map(CGPoint(x: 0, y: b.maxY * 1.05)))
        var lightCtx = ctx
        lightCtx.clip(to: body)
        lightCtx.stroke(lit, with: .color(Color.white.opacity(0.16 * opacity)),
                        lineWidth: max(1, 5 * scale))

        var shade = Path()
        shade.move(to: map(CGPoint(x: b.minX, y: b.minY * 0.40)))
        shade.addQuadCurve(to: map(CGPoint(x: b.maxX, y: b.minY * 0.35)),
                           control: map(CGPoint(x: 0, y: b.minY * 1.08)))
        lightCtx.stroke(shade, with: .color(CBTheme.ink.opacity(0.14 * opacity)),
                        lineWidth: max(1, 6 * scale))

        // Rim
        ctx.stroke(body, with: .color((outline ?? CBTheme.ink.opacity(0.35)).opacity(opacity)),
                   lineWidth: max(0.6, 1.1 * scale))
    }

    private static func drawTexture(_ ctx: inout GraphicsContext,
                                    kind: CBStoneKind,
                                    map: (CGPoint) -> CGPoint,
                                    scale: CGFloat,
                                    opacity: Double) {
        let b = kind.poly
        let w = b.maxX - b.minX
        let h = b.maxY - b.minY
        guard w > 0, h > 0 else { return }
        let light = Color.white.opacity(0.20 * opacity)
        let dark = CBTheme.ink.opacity(0.16 * opacity)

        switch kind.texture {
        case .speckle:
            var s = UInt64(kind.id + 7) &* 0x9E3779B97F4A7C15
            let n = 26 + kind.id % 9
            for _ in 0..<n {
                s = s &* 6364136223846793005 &+ 1442695040888963407
                let a = Double((s >> 33) & 0xFFFF) / 65535.0
                s = s &* 6364136223846793005 &+ 1442695040888963407
                let c = Double((s >> 33) & 0xFFFF) / 65535.0
                s = s &* 6364136223846793005 &+ 1442695040888963407
                let d = Double((s >> 33) & 0xFFFF) / 65535.0
                let local = CGPoint(x: b.minX + a * w, y: b.minY + c * h)
                let p = map(local)
                let r = max(0.5, CGFloat(0.9 + d * 1.6) * scale)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r / 2, y: p.y - r / 2, width: r, height: r)),
                         with: .color(d > 0.5 ? light : dark))
            }

        case .banding:
            let bands = 5 + kind.id % 3
            for i in 0..<bands {
                let t = Double(i + 1) / Double(bands + 1)
                let y = b.minY + t * h
                var p = Path()
                p.move(to: map(CGPoint(x: b.minX - 2, y: y)))
                p.addQuadCurve(to: map(CGPoint(x: b.maxX + 2, y: y + h * 0.04)),
                               control: map(CGPoint(x: 0, y: y + h * 0.10)))
                ctx.stroke(p, with: .color(i % 2 == 0 ? dark : light),
                           lineWidth: max(0.5, CGFloat(1.0 + Double(i % 2)) * scale))
            }

        case .veins:
            for i in 0..<3 {
                let off = Double(i) * 0.22 - 0.22
                var p = Path()
                p.move(to: map(CGPoint(x: b.minX - 2, y: b.minY + h * (0.30 + off))))
                p.addCurve(to: map(CGPoint(x: b.maxX + 2, y: b.minY + h * (0.66 + off))),
                           control1: map(CGPoint(x: b.minX + w * 0.35, y: b.minY + h * (0.72 + off))),
                           control2: map(CGPoint(x: b.minX + w * 0.62, y: b.minY + h * (0.24 + off))))
                ctx.stroke(p, with: .color(i == 1 ? light : dark), lineWidth: max(0.5, 1.2 * scale))
            }

        case .grain:
            let cols = 7
            for i in 0..<cols {
                let x = b.minX + (Double(i) + 0.5) / Double(cols) * w
                var p = Path()
                p.move(to: map(CGPoint(x: x, y: b.minY + h * 0.18)))
                p.addLine(to: map(CGPoint(x: x + w * 0.05, y: b.minY + h * 0.82)))
                ctx.stroke(p, with: .color(i % 2 == 0 ? dark : light), lineWidth: max(0.5, 0.9 * scale))
            }

        case .rings:
            for i in 1...3 {
                let f = Double(i) / 4.0
                var p = Path()
                let steps = 26
                for k in 0...steps {
                    let a = Double(k) / Double(steps) * 2 * Double.pi
                    let local = CGPoint(x: Double(b.centroid.x) + cos(a) * w * 0.5 * f,
                                        y: Double(b.centroid.y) + sin(a) * h * 0.5 * f)
                    let q = map(local)
                    if k == 0 { p.move(to: q) } else { p.addLine(to: q) }
                }
                p.closeSubpath()
                ctx.stroke(p, with: .color(i % 2 == 0 ? light : dark), lineWidth: max(0.5, 0.9 * scale))
            }
        }
    }

    /// Draws the plinth the cairn stands on.
    static func drawBase(_ ctx: inout GraphicsContext, map: (CGPoint) -> CGPoint, scale: CGFloat) {
        var p = Path()
        let pts = CBCatalog.base.points
        guard pts.count >= 3 else { return }
        p.move(to: map(pts[0]))
        for i in 1..<pts.count { p.addLine(to: map(pts[i])) }
        p.closeSubpath()
        ctx.fill(p, with: .color(CBTheme.slate.opacity(0.88)))
        var sub = ctx
        sub.clip(to: p)
        for i in 0..<5 {
            var line = Path()
            let y = -6.0 - Double(i) * 7.0
            line.move(to: map(CGPoint(x: -100, y: y)))
            line.addQuadCurve(to: map(CGPoint(x: 100, y: y + 3)),
                              control: map(CGPoint(x: 0, y: y + 8)))
            sub.stroke(line, with: .color(Color.white.opacity(0.07)), lineWidth: max(0.6, 1.4 * scale))
        }
        ctx.stroke(p, with: .color(CBTheme.ink.opacity(0.45)), lineWidth: max(0.6, 1.2 * scale))
    }

    // MARK: - Fitted cairn drawing (gallery + previews)

    /// Draws a whole saved cairn scaled to fit `rect`, including the plinth.
    static func drawCairn(_ ctx: inout GraphicsContext,
                          kindIDs: [Int], xs: [Double], ys: [Double], rots: [Double],
                          in rect: CGRect, withBase: Bool) {
        let n = min(kindIDs.count, min(xs.count, min(ys.count, rots.count)))
        guard n > 0 else { return }

        // world bounds of everything drawn
        var minX = Double.greatestFiniteMagnitude, maxX = -Double.greatestFiniteMagnitude
        var minY = Double.greatestFiniteMagnitude, maxY = -Double.greatestFiniteMagnitude
        func expand(_ pts: [CGPoint]) {
            for p in pts {
                minX = Swift.min(minX, Double(p.x)); maxX = Swift.max(maxX, Double(p.x))
                minY = Swift.min(minY, Double(p.y)); maxY = Swift.max(maxY, Double(p.y))
            }
        }
        var anchorX = 0.0
        for i in 0..<n { anchorX += xs[i] }
        anchorX = cbSafeDivide(anchorX, Double(n))

        if withBase {
            expand(cbWorldPoints(CBCatalog.base, position: CGPoint(x: anchorX, y: 0), rotation: 0))
        }
        for i in 0..<n {
            let k = CBCatalog.kind(kindIDs[i])
            expand(cbWorldPoints(k.poly, position: CGPoint(x: xs[i], y: ys[i]), rotation: rots[i]))
        }
        guard maxX > minX, maxY > minY else { return }

        let wSpan = maxX - minX, hSpan = maxY - minY
        let s = Swift.min(cbSafeDivide(Double(rect.width), wSpan, fallback: 1),
                          cbSafeDivide(Double(rect.height), hSpan, fallback: 1))
        let scale = CGFloat(Swift.max(0.01, s))
        let cx = (minX + maxX) / 2, cy = (minY + maxY) / 2

        func toScreen(_ w: CGPoint) -> CGPoint {
            CGPoint(x: rect.midX + (CGFloat(w.x) - CGFloat(cx)) * scale,
                    y: rect.midY - (CGFloat(w.y) - CGFloat(cy)) * scale)
        }

        if withBase {
            drawBase(&ctx, map: { local in
                toScreen(CGPoint(x: anchorX + Double(local.x), y: Double(local.y)))
            }, scale: scale)
        }
        for i in 0..<n {
            let k = CBCatalog.kind(kindIDs[i])
            let pos = CGPoint(x: xs[i], y: ys[i])
            let rot = rots[i]
            let c = cos(rot), sn = sin(rot)
            drawStone(&ctx, kind: k, map: { local in
                let wx = Double(pos.x) + Double(local.x) * c - Double(local.y) * sn
                let wy = Double(pos.y) + Double(local.x) * sn + Double(local.y) * c
                return toScreen(CGPoint(x: wx, y: wy))
            }, scale: scale)
        }
    }
}

// MARK: - Single stone portrait (Stones tab, trial rosters)

struct CBStonePortrait: View {
    let kindID: Int
    var boxSize: CGSize
    var locked: Bool = false

    var body: some View {
        Canvas { ctx, _ in
            let kind = CBCatalog.kind(kindID)
            let rect = CGRect(x: 4, y: 4, width: boxSize.width - 8, height: boxSize.height - 8)
            let w = kind.poly.maxX - kind.poly.minX
            let h = kind.poly.maxY - kind.poly.minY
            guard w > 0, h > 0 else { return }
            let s = CGFloat(Swift.min(cbSafeDivide(Double(rect.width), w, fallback: 1),
                                      cbSafeDivide(Double(rect.height), h, fallback: 1)))
            let cx = (kind.poly.minX + kind.poly.maxX) / 2
            let cy = (kind.poly.minY + kind.poly.maxY) / 2
            var context = ctx
            if locked {
                context.opacity = 0.30
            }
            CBRender.drawStone(&context, kind: kind, map: { local in
                CGPoint(x: rect.midX + (CGFloat(local.x) - CGFloat(cx)) * s,
                        y: rect.midY - (CGFloat(local.y) - CGFloat(cy)) * s)
            }, scale: s)
        }
        .frame(width: boxSize.width, height: boxSize.height)
        .allowsHitTesting(false)
    }
}
