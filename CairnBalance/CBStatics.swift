import CoreGraphics
import Foundation

// MARK: - Surface height field
//
// Instead of a general collision engine the cairn keeps a 1 pt resolution
// height field of everything already resting. Settling and contact-finding then
// become cheap array lookups, and — crucially — they are deterministic, so the
// live preview shows exactly the seat the release will produce.

struct CBHeightField {
    private(set) var tops: [Double]      // -inf where nothing is below
    private(set) var owners: [Int]       // -1 nothing, -2 the base, else placement index
    let width: Double

    init(width: Double) {
        self.width = Swift.max(8, width)
        let n = Int(self.width) + 1
        tops = [Double](repeating: -Double.greatestFiniteMagnitude, count: n)
        owners = [Int](repeating: -1, count: n)
    }

    var sampleCount: Int { tops.count }

    @inline(__always)
    func index(forX x: Double) -> Int? {
        guard x.isFinite else { return nil }
        let i = Int(x.rounded())
        guard i >= 0, i < tops.count else { return nil }
        return i
    }

    /// Highest solid surface at x, or nil when there is nothing below.
    @inline(__always)
    func top(at x: Double) -> Double? {
        guard let i = index(forX: x) else { return nil }
        let v = tops[i]
        return v > -1e17 ? v : nil
    }

    @inline(__always)
    func owner(at x: Double) -> Int {
        guard let i = index(forX: x) else { return -1 }
        return owners[i]
    }

    mutating func add(points: [CGPoint], owner: Int) {
        let b = cbBounds(points)
        guard b.maxX > b.minX else { return }
        let lo = Swift.max(0, Int(b.minX.rounded(.down)))
        let hi = Swift.min(tops.count - 1, Int(b.maxX.rounded(.up)))
        guard lo <= hi else { return }
        for i in lo...hi {
            guard let span = cbVerticalSpan(points, atX: Double(i)) else { continue }
            if span.hi > tops[i] {
                tops[i] = span.hi
                owners[i] = owner
            }
        }
    }
}

// MARK: - Settling
//
// A dropped stone falls straight down until first contact, then — if it landed
// on a knife edge — tips about that contact point until a second point touches.
// That is the whole "physics": no restitution, no bounce, no iteration to a
// fixed point. Two passes and it is seated.

struct CBSettleResult {
    var position: CGPoint
    var rotation: Double
    var contactL: Double
    var contactR: Double
    var contactY: Double
    var supported: Bool
    /// Highest thing the seat actually touches: -1 nothing, -2 the plinth,
    /// otherwise the placement index. A cairn only grows on its own crown.
    var topOwner: Int = -1
    /// Set by the engine: does this seat actually touch the crown of the cairn?
    var onCrown: Bool = true

    var seatWidth: Double { Swift.max(0, contactR - contactL) }
}

enum CBStatics {

    static let contactEpsilon: Double = 0.9
    static let penetrationTolerance: Double = 0.7
    static let maxTipAngle: Double = 0.40          // ~23 degrees
    static let tipStep: Double = 0.0075            // ~0.43 degrees
    /// Below this the landing counts as a knife edge and the stone rocks.
    static let seatWidthForTipping: Double = 9.0

    /// Vertical gap between a stone's underside and the field. Positive = floating.
    private static func minimumGap(_ pts: [CGPoint], _ field: CBHeightField) -> (gap: Double, anyContact: Bool) {
        let b = cbBounds(pts)
        let lo = Swift.max(0, Int(b.minX.rounded(.down)))
        let hi = Swift.min(field.sampleCount - 1, Int(b.maxX.rounded(.up)))
        guard lo <= hi else { return (0, false) }
        var best = Double.greatestFiniteMagnitude
        var found = false
        var i = lo
        while i <= hi {
            if let surface = field.top(at: Double(i)),
               let span = cbVerticalSpan(pts, atX: Double(i)) {
                let gap = span.lo - surface
                if gap < best { best = gap }
                found = true
            }
            i += 1
        }
        return found ? (best, true) : (0, false)
    }

    /// Sampled x positions where the stone is touching the field.
    private static func contactSpan(_ pts: [CGPoint], _ field: CBHeightField, epsilon: Double)
        -> (l: Double, r: Double, y: Double, owner: Int)? {
        let b = cbBounds(pts)
        let lo = Swift.max(0, Int(b.minX.rounded(.down)))
        let hi = Swift.min(field.sampleCount - 1, Int(b.maxX.rounded(.up)))
        guard lo <= hi else { return nil }
        var l = Double.greatestFiniteMagnitude
        var r = -Double.greatestFiniteMagnitude
        var ySum = 0.0
        var n = 0
        var owner = Int.min
        var i = lo
        while i <= hi {
            if let surface = field.top(at: Double(i)),
               let span = cbVerticalSpan(pts, atX: Double(i)) {
                if span.lo - surface <= epsilon {
                    l = Swift.min(l, Double(i))
                    r = Swift.max(r, Double(i))
                    ySum += surface
                    n += 1
                    let o = field.owner(at: Double(i))
                    if o > owner { owner = o }
                }
            }
            i += 1
        }
        guard n > 0, l.isFinite, r.isFinite else { return nil }
        return (l, r, cbSafeDivide(ySum, Double(n)), owner == Int.min ? -1 : owner)
    }

    /// Drop + tip. `startPos` is where the player is holding the stone.
    static func settle(kind: CBStoneKind,
                       startPos: CGPoint,
                       rotation: Double,
                       field: CBHeightField) -> CBSettleResult {

        var pos = startPos
        var rot = rotation
        var pts = cbWorldPoints(kind.poly, position: pos, rotation: rot)

        // 1. straight fall
        let probe = minimumGap(pts, field)
        guard probe.anyContact else {
            return CBSettleResult(position: pos, rotation: rot,
                                  contactL: 0, contactR: 0, contactY: 0, supported: false)
        }
        pos.y -= CGFloat(probe.gap)
        pts = cbWorldPoints(kind.poly, position: pos, rotation: rot)

        guard var seat = contactSpan(pts, field, epsilon: contactEpsilon) else {
            return CBSettleResult(position: pos, rotation: rot,
                                  contactL: 0, contactR: 0, contactY: 0, supported: false)
        }

        // 2. tip about the contact point until a second point lands
        if seat.r - seat.l < CBStatics.seatWidthForTipping {
            let pivot = CGPoint(x: (seat.l + seat.r) * 0.5, y: seat.y)
            var steps = 0
            let maxSteps = Int(maxTipAngle / tipStep)
            var lastGoodPos = pos
            var lastGoodRot = rot

            while steps < maxSteps {
                let com = cbWorldCentroid(kind.poly, position: pos, rotation: rot)
                let lever = Double(com.x) - Double(pivot.x)
                if abs(lever) < 0.25 { break }           // balanced over the point
                let dTheta = -tipStep * (lever > 0 ? 1.0 : -1.0)

                let newPos = cbRotateAbout(pos, pivot: pivot, angle: dTheta)
                let newRot = rot + dTheta
                let newPts = cbWorldPoints(kind.poly, position: newPos, rotation: newRot)

                // penetration check against everything already resting
                let g = minimumGap(newPts, field)
                if !g.anyContact { break }
                if -g.gap > penetrationTolerance {
                    break                                 // the far side has landed
                }
                lastGoodPos = newPos; lastGoodRot = newRot
                pos = newPos; rot = newRot
                pts = newPts
                steps += 1
            }
            pos = lastGoodPos; rot = lastGoodRot
            pts = cbWorldPoints(kind.poly, position: pos, rotation: rot)

            // re-seat vertically after the tip so it is neither floating nor sunk
            let g2 = minimumGap(pts, field)
            if g2.anyContact, g2.gap.isFinite {
                pos.y -= CGFloat(g2.gap)
                pts = cbWorldPoints(kind.poly, position: pos, rotation: rot)
            }
            if let s2 = contactSpan(pts, field, epsilon: contactEpsilon + 0.6) {
                seat = s2
            }
        }

        return CBSettleResult(position: pos, rotation: rot,
                              contactL: seat.l, contactR: seat.r, contactY: seat.y,
                              supported: true, topOwner: seat.owner)
    }
}

// MARK: - Stability
//
// For every contact level, gather the mass and first moment of everything above
// it, project the combined centre of mass onto the ground plane and ask whether
// that projection lands inside the support interval. Wind is folded in as a
// lateral acceleration acting at the group's centre of mass height.

struct CBLevel: Identifiable {
    let id: Int                  // placement index of the stone sitting on this contact
    let xL: Double
    let xR: Double
    let y: Double
    let comX: Double             // combined COM of everything from this level up
    let comY: Double
    let effectiveComX: Double    // after wind
    let mass: Double
    let margin: Double           // -1 ... 1, negative means torque wins

    var seatWidth: Double { Swift.max(0, xR - xL) }
}

enum CBStability {

    /// margin = min(comX - xL, xR - comX) / (0.5 * (xR - xL)) clamped to [-1, 1].
    static func margin(comX: Double, xL: Double, xR: Double) -> Double {
        let half = (xR - xL) * 0.5
        let guardedHalf = Swift.max(0.5, half)       // never divide by a zero-width contact
        let left = comX - xL
        let right = xR - comX
        let raw = cbSafeDivide(Swift.min(left, right), guardedHalf, fallback: -1)
        return cbClamp(raw, -1, 1)
    }

    static func evaluate(placed: [CBPlacedStone],
                         catalog: [CBStoneKind],
                         windAccel: Double) -> [CBLevel] {
        guard !placed.isEmpty else { return [] }
        var levels: [CBLevel] = []
        levels.reserveCapacity(placed.count)

        // walk from the top down, accumulating mass and moments
        var mass = 0.0
        var mx = 0.0
        var my = 0.0
        var acc: [(m: Double, x: Double, y: Double)] = []
        acc.reserveCapacity(placed.count)

        for s in placed {
            guard s.kindID >= 0, s.kindID < catalog.count else {
                acc.append((0, 0, 0)); continue
            }
            let k = catalog[s.kindID]
            let c = cbWorldCentroid(k.poly, position: s.position, rotation: s.rotation)
            acc.append((k.mass, Double(c.x), Double(c.y)))
        }

        var i = placed.count - 1
        while i >= 0 {
            let a = acc[i]
            mass += a.m
            mx += a.m * a.x
            my += a.m * a.y

            let comX = cbSafeDivide(mx, mass, fallback: Double(placed[i].position.x))
            let comY = cbSafeDivide(my, mass, fallback: Double(placed[i].position.y))

            // Lateral wind acceleration (in units of g) applied at the group COM
            // shifts the effective ground projection by a*(comY - contactY).
            let lever = Swift.max(0, comY - placed[i].contactY)
            let shift = windAccel * lever
            let effX = comX + (shift.isFinite ? shift : 0)

            let m = margin(comX: effX, xL: placed[i].contactL, xR: placed[i].contactR)
            levels.append(CBLevel(id: i,
                                  xL: placed[i].contactL,
                                  xR: placed[i].contactR,
                                  y: placed[i].contactY,
                                  comX: comX, comY: comY,
                                  effectiveComX: effX,
                                  mass: mass,
                                  margin: m))
            i -= 1
        }
        return levels.reversed()
    }

    /// Overall stack stability = the weakest level.
    static func weakest(_ levels: [CBLevel]) -> CBLevel? {
        levels.min(by: { $0.margin < $1.margin })
    }
}

// MARK: - Topple
//
// The failing level and everything above it rotate about the nearer support
// edge. Angular acceleration comes from the unbalanced torque with the group
// treated as a point mass at its COM: alpha = g * (comX - pivotX) / r^2.

struct CBToppleState {
    var fromIndex: Int
    var pivot: CGPoint
    var angle: Double = 0
    var omega: Double = 0
    var drop: Double = 0
    var fade: Double = 1
    var elapsed: Double = 0

    var finished: Bool { fade <= 0.01 }
}

enum CBTopple {
    static let gravity: Double = 900.0    // points / s^2

    static func begin(level: CBLevel) -> CBToppleState {
        let goesRight = level.effectiveComX > (level.xL + level.xR) * 0.5
        let pivotX = goesRight ? level.xR : level.xL
        return CBToppleState(fromIndex: level.id,
                             pivot: CGPoint(x: pivotX, y: level.y))
    }

    static func step(_ s: inout CBToppleState, comX: Double, comY: Double, dt: Double) {
        let rx = comX - Double(s.pivot.x)
        let ry = Swift.max(6.0, comY - Double(s.pivot.y))
        let r2 = Swift.max(64.0, rx * rx + ry * ry)
        var alpha = cbSafeDivide(-gravity * rx, r2)
        if abs(rx) < 0.5 { alpha = rx >= 0 ? -0.6 : 0.6 }   // nudge a perfectly balanced pile
        s.omega += alpha * dt
        s.angle += s.omega * dt
        s.elapsed += dt
        if abs(s.angle) > 0.85 {
            s.drop += (s.elapsed - 0.2) * gravity * dt * 0.55
        }
        if s.elapsed > 1.05 {
            s.fade = Swift.max(0, s.fade - dt * 1.7)
        }
    }
}

// MARK: - Wind
//
// Deterministic sine stack — same schedule every run of a given seed, no RNG at
// draw time, so the gauge and the statics can never disagree.

enum CBWind {
    static func accel(t: Double, seed: UInt64, strength: Double) -> Double {
        guard strength > 0 else { return 0 }
        let phase = Double(seed % 997) * 0.0063
        let a = sin(t * 0.31 + phase) * 0.58
        let b = sin(t * 0.83 + phase * 2.3 + 1.7) * 0.27
        let c = sin(t * 1.97 + phase * 0.7 + 3.1) * 0.11
        let d = sin(t * 0.11 + phase * 1.4) * 0.22
        let v = (a + b + c + d) * strength
        return v.isFinite ? v : 0
    }
}

// MARK: - Deterministic seeded generator (FNV-1a + xorshift)

struct CBSeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    static func fnv1a(_ s: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in s.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func int(_ upper: Int) -> Int {
        guard upper > 0 else { return 0 }
        return Int(next() % UInt64(upper))
    }

    mutating func unit() -> Double {
        Double(next() % 1_000_000) / 1_000_000.0
    }

    mutating func pick<T>(_ arr: [T]) -> T? {
        guard !arr.isEmpty else { return nil }
        return arr[int(arr.count)]
    }
}
