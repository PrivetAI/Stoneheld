import CoreGraphics
import Foundation

// MARK: - Numeric guards
// Every division in the statics core funnels through here. A degenerate contact
// (zero width) must never let NaN or Infinity reach the UI.

@inline(__always)
func cbSafeDivide(_ a: Double, _ b: Double, fallback: Double = 0) -> Double {
    guard a.isFinite, b.isFinite, b != 0 else { return fallback }
    let r = a / b
    return r.isFinite ? r : fallback
}

@inline(__always)
func cbClamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
    guard v.isFinite else { return lo }
    return Swift.min(hi, Swift.max(lo, v))
}

// MARK: - Convex polygon
//
// Local coordinates, y pointing UP (mathematical convention). The renderer flips
// to screen space; the statics never has to think about screen orientation.

struct SHPolygon {
    let points: [CGPoint]        // counter-clockwise, convex
    let area: Double             // shoelace
    let centroid: CGPoint        // polygon centroid via the first-moment formula
    let minX: Double
    let maxX: Double
    let minY: Double
    let maxY: Double
    let boundRadius: Double      // max distance from centroid, for cheap culling

    init(_ raw: [CGPoint]) {
        let hull = SHPolygon.convexHull(raw)
        var pts = hull
        if SHPolygon.signedArea(pts) < 0 { pts.reverse() }
        if pts.count < 3 {
            // Degenerate input can never happen with the authored catalogue, but
            // a triangle fallback keeps every downstream routine total.
            pts = [CGPoint(x: -4, y: -4), CGPoint(x: 4, y: -4), CGPoint(x: 0, y: 4)]
        }
        self.points = pts

        let a = SHPolygon.signedArea(pts)
        self.area = abs(a)
        self.centroid = SHPolygon.momentCentroid(pts, signedArea: a)

        var lx = Double.greatestFiniteMagnitude, hx = -Double.greatestFiniteMagnitude
        var ly = Double.greatestFiniteMagnitude, hy = -Double.greatestFiniteMagnitude
        for p in pts {
            lx = Swift.min(lx, Double(p.x)); hx = Swift.max(hx, Double(p.x))
            ly = Swift.min(ly, Double(p.y)); hy = Swift.max(hy, Double(p.y))
        }
        self.minX = lx; self.maxX = hx; self.minY = ly; self.maxY = hy

        var r = 0.0
        for p in pts {
            let dx = Double(p.x) - Double(centroid.x)
            let dy = Double(p.y) - Double(centroid.y)
            r = Swift.max(r, (dx * dx + dy * dy).squareRoot())
        }
        self.boundRadius = r
    }

    // Shoelace: A = 1/2 * sum( x_i * y_{i+1} - x_{i+1} * y_i )
    static func signedArea(_ p: [CGPoint]) -> Double {
        guard p.count >= 3 else { return 0 }
        var s = 0.0
        for i in 0..<p.count {
            let a = p[i], b = p[(i + 1) % p.count]
            s += Double(a.x) * Double(b.y) - Double(b.x) * Double(a.y)
        }
        return s * 0.5
    }

    // Cx = 1/(6A) * sum( (x_i + x_{i+1}) * cross_i ),  Cy analogous.
    static func momentCentroid(_ p: [CGPoint], signedArea a: Double) -> CGPoint {
        guard p.count >= 3 else { return .zero }
        if abs(a) < 1e-9 {
            // Collinear fallback: plain vertex average.
            var sx = 0.0, sy = 0.0
            for q in p { sx += Double(q.x); sy += Double(q.y) }
            return CGPoint(x: cbSafeDivide(sx, Double(p.count)), y: cbSafeDivide(sy, Double(p.count)))
        }
        var cx = 0.0, cy = 0.0
        for i in 0..<p.count {
            let u = p[i], v = p[(i + 1) % p.count]
            let cross = Double(u.x) * Double(v.y) - Double(v.x) * Double(u.y)
            cx += (Double(u.x) + Double(v.x)) * cross
            cy += (Double(u.y) + Double(v.y)) * cross
        }
        let denom = 6.0 * a
        return CGPoint(x: cbSafeDivide(cx, denom), y: cbSafeDivide(cy, denom))
    }

    /// Andrew's monotone chain. Guarantees convexity even if an authored outline
    /// slips slightly concave.
    static func convexHull(_ input: [CGPoint]) -> [CGPoint] {
        guard input.count >= 3 else { return input }
        let pts = input.sorted { a, b in
            a.x == b.x ? a.y < b.y : a.x < b.x
        }
        func cross(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Double {
            (Double(a.x) - Double(o.x)) * (Double(b.y) - Double(o.y))
            - (Double(a.y) - Double(o.y)) * (Double(b.x) - Double(o.x))
        }
        var lower: [CGPoint] = []
        for p in pts {
            while lower.count >= 2, cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 {
                lower.removeLast()
            }
            lower.append(p)
        }
        var upper: [CGPoint] = []
        for p in pts.reversed() {
            while upper.count >= 2, cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 {
                upper.removeLast()
            }
            upper.append(p)
        }
        lower.removeLast(); upper.removeLast()
        let hull = lower + upper
        return hull.count >= 3 ? hull : input
    }
}

// MARK: - World transform

@inline(__always)
func cbRotate(_ p: CGPoint, _ angle: Double) -> CGPoint {
    let c = cos(angle), s = sin(angle)
    return CGPoint(x: Double(p.x) * c - Double(p.y) * s,
                   y: Double(p.x) * s + Double(p.y) * c)
}

@inline(__always)
func cbRotateAbout(_ p: CGPoint, pivot: CGPoint, angle: Double) -> CGPoint {
    let d = CGPoint(x: Double(p.x) - Double(pivot.x), y: Double(p.y) - Double(pivot.y))
    let r = cbRotate(d, angle)
    return CGPoint(x: Double(pivot.x) + Double(r.x), y: Double(pivot.y) + Double(r.y))
}

/// Local polygon vertices rotated then translated into world space.
func cbWorldPoints(_ poly: SHPolygon, position: CGPoint, rotation: Double) -> [CGPoint] {
    let c = cos(rotation), s = sin(rotation)
    return poly.points.map { p in
        CGPoint(x: Double(position.x) + Double(p.x) * c - Double(p.y) * s,
                y: Double(position.y) + Double(p.x) * s + Double(p.y) * c)
    }
}

func cbWorldCentroid(_ poly: SHPolygon, position: CGPoint, rotation: Double) -> CGPoint {
    let r = cbRotate(poly.centroid, rotation)
    return CGPoint(x: Double(position.x) + Double(r.x), y: Double(position.y) + Double(r.y))
}

// MARK: - Convex polygon queries (world space)

/// Vertical slab through a convex polygon: returns (lowest y, highest y) at x.
func cbVerticalSpan(_ pts: [CGPoint], atX x: Double) -> (lo: Double, hi: Double)? {
    guard pts.count >= 3 else { return nil }
    var lo = Double.greatestFiniteMagnitude
    var hi = -Double.greatestFiniteMagnitude
    var hit = false
    for i in 0..<pts.count {
        let a = pts[i], b = pts[(i + 1) % pts.count]
        let ax = Double(a.x), bx = Double(b.x)
        let ay = Double(a.y), by = Double(b.y)
        let lowX = Swift.min(ax, bx), highX = Swift.max(ax, bx)
        guard x >= lowX - 1e-9, x <= highX + 1e-9 else { continue }
        if abs(bx - ax) < 1e-9 {
            lo = Swift.min(lo, Swift.min(ay, by)); hi = Swift.max(hi, Swift.max(ay, by))
            hit = true
        } else {
            let t = cbSafeDivide(x - ax, bx - ax)
            let y = ay + t * (by - ay)
            if y.isFinite { lo = Swift.min(lo, y); hi = Swift.max(hi, y); hit = true }
        }
    }
    guard hit, lo.isFinite, hi.isFinite else { return nil }
    return (lo, hi)
}

/// Point-in-convex-polygon. Used for hit-testing from a single canvas-wide
/// gesture — no stacked invisible buttons anywhere in this app.
func cbPointInConvex(_ pts: [CGPoint], _ p: CGPoint) -> Bool {
    guard pts.count >= 3 else { return false }
    var sign = 0
    for i in 0..<pts.count {
        let a = pts[i], b = pts[(i + 1) % pts.count]
        let cross = (Double(b.x) - Double(a.x)) * (Double(p.y) - Double(a.y))
                  - (Double(b.y) - Double(a.y)) * (Double(p.x) - Double(a.x))
        if cross > 1e-9 {
            if sign < 0 { return false }
            sign = 1
        } else if cross < -1e-9 {
            if sign > 0 { return false }
            sign = -1
        }
    }
    return true
}

func cbBounds(_ pts: [CGPoint]) -> (minX: Double, maxX: Double, minY: Double, maxY: Double) {
    var lx = Double.greatestFiniteMagnitude, hx = -Double.greatestFiniteMagnitude
    var ly = Double.greatestFiniteMagnitude, hy = -Double.greatestFiniteMagnitude
    for p in pts {
        lx = Swift.min(lx, Double(p.x)); hx = Swift.max(hx, Double(p.x))
        ly = Swift.min(ly, Double(p.y)); hy = Swift.max(hy, Double(p.y))
    }
    if !lx.isFinite { return (0, 0, 0, 0) }
    return (lx, hx, ly, hy)
}

// MARK: - Stone catalogue entry

enum SHTexture: Int {
    case speckle, banding, veins, grain, rings
}

enum SHUnlock {
    case start
    case placed(Int)
    case stars(Int)
}

struct SHStoneKind {
    let id: Int
    let name: String
    let shore: Int              // 0 Pebble Cove, 1 Slate Quarry, 2 River Bend, 3 Basalt Point
    let poly: SHPolygon
    let density: Double
    let tint: Int               // index into SHTheme.stoneTints
    let texture: SHTexture
    let unlock: SHUnlock
    let note: String

    var mass: Double { poly.area * density }
    var width: Double { poly.maxX - poly.minX }
    var height: Double { poly.maxY - poly.minY }
}

/// A stone that has been committed to the cairn.
struct SHPlacedStone: Identifiable {
    let id: Int                 // placement index within this run
    let kindID: Int
    var position: CGPoint
    var rotation: Double
    var contactL: Double
    var contactR: Double
    var contactY: Double
}
