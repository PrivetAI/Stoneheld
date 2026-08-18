import SwiftUI
import Combine

// MARK: - Daily cairn seeding
//
// Seeded from the calendar day string through FNV-1a, so the same day always
// produces the same twelve stones, offline, forever. Never a network clock.

enum CBDaily {
    static func todayKey() -> String {
        CBFormat.dayKeyFormatter.string(from: Date())
    }

    static func key(for date: Date) -> String {
        CBFormat.dayKeyFormatter.string(from: date)
    }

    static func seed(for dayKey: String) -> UInt64 {
        CBSeededRandom.fnv1a("cairn-balance|" + dayKey)
    }

    /// Twelve stones drawn from the whole shore, weighted so the run starts
    /// broad and finishes narrow — the same shape of challenge every day.
    static func stones(for dayKey: String) -> [Int] {
        var rng = CBSeededRandom(seed: seed(for: dayKey))
        var out: [Int] = []
        let quarry = Array(9...17)
        let cove = Array(0...8)
        let river = Array(18...26)
        let point = Array(27...35)

        out.append(quarry[rng.int(quarry.count)])
        out.append(quarry[rng.int(quarry.count)])
        for _ in 0..<3 {
            let pool = rng.unit() < 0.5 ? cove : river
            out.append(pool[rng.int(pool.count)])
        }
        for _ in 0..<3 {
            let r = rng.unit()
            let pool = r < 0.34 ? cove : (r < 0.72 ? river : quarry)
            out.append(pool[rng.int(pool.count)])
        }
        for _ in 0..<2 {
            let pool = rng.unit() < 0.6 ? river : point
            out.append(pool[rng.int(pool.count)])
        }
        out.append(point[rng.int(point.count)])
        out.append(point[rng.int(point.count)])
        return out
    }

    static func lastDays(_ n: Int) -> [String] {
        let cal = Calendar(identifier: .gregorian)
        var out: [String] = []
        let today = Date()
        for i in stride(from: n - 1, through: 0, by: -1) {
            if let d = cal.date(byAdding: .day, value: -i, to: today) {
                out.append(key(for: d))
            }
        }
        return out
    }
}

// MARK: - Run result

struct CBRunResult {
    var mode: CBMode
    var toppled: Bool
    var stones: Int
    var height: Double
    var minMargin: Double
    var metric: Double
    var stars: Int
    var passed: Bool
    var trialID: Int?
    var dayKey: String?
    var newRecord: Bool
    var failedLevel: Int?      // placement index of the contact that gave way
}

// MARK: - Engine

final class CBEngine: ObservableObject {

    enum Phase { case placing, settling, toppling, over }

    // A single published counter drives every redraw; the rest is plain state so
    // one animation frame never fires a dozen separate publishes.
    @Published private(set) var frame: Int = 0

    private(set) var mode: CBMode = .zen
    private(set) var trial: CBTrial?
    private(set) var dayKey: String = ""
    private(set) var windStrength: Double = 0

    var phase: Phase = .placing
    var placed: [CBPlacedStone] = []
    var lastStable: [CBPlacedStone] = []
    var queue: [Int] = []
    var queueIndex: Int = 0

    var holdX: Double = 0
    var holdRot: Double = 0
    var preview: CBSettleResult?
    var levels: [CBLevel] = []
    var weakest: CBLevel?
    var topple: CBToppleState?

    var cameraY: Double = 0
    var windAccel: Double = 0
    var windTime: Double = 0
    var pulse: Double = 0
    var hint: String = ""
    var result: CBRunResult?

    var bestHeightThisRun: Double = 0
    var minMarginThisRun: Double = 1

    private(set) var boardSize: CGSize = CGSize(width: 375, height: 480)
    private var field = CBHeightField(width: 375)
    private var rng = CBSeededRandom(seed: 1)
    private var timer: Timer?

    private var settleFrom: (pos: CGPoint, rot: Double) = (.zero, 0)
    private var settleTo: CBSettleResult?
    private var settleT: Double = 0

    // Layout constants for the world -> screen mapping.
    let groundInset: Double = 56
    private let stoneCap = 46

    // MARK: - Lifecycle

    func start(mode: CBMode, trial: CBTrial?, dayKey: String, boardSize: CGSize, store: CBStore) {
        self.mode = mode
        self.trial = trial
        self.dayKey = dayKey
        self.boardSize = CGSize(width: max(240, boardSize.width), height: max(240, boardSize.height))

        switch mode {
        case .zen:      windStrength = store.data.zenWind ? 0.030 : 0
        case .windward: windStrength = 0.085
        case .trials:   windStrength = trial?.wind ?? 0
        case .daily:    windStrength = 0
        }

        placed = []
        lastStable = []
        queueIndex = 0
        phase = .placing
        levels = []
        weakest = nil
        topple = nil
        cameraY = 0
        windTime = 0
        windAccel = 0
        pulse = 0
        hint = ""
        result = nil
        bestHeightThisRun = 0
        minMarginThisRun = 1
        settleTo = nil

        switch mode {
        case .trials:
            queue = trial?.stones ?? []
            rng = CBSeededRandom(seed: UInt64((trial?.id ?? 1) * 7919))
        case .daily:
            queue = CBDaily.stones(for: dayKey)
            rng = CBSeededRandom(seed: CBDaily.seed(for: dayKey))
        case .zen, .windward:
            rng = CBSeededRandom(seed: UInt64(Date().timeIntervalSince1970.rounded()) &* 2654435761)
            queue = []
            refillQueue(store: store)
        }

        rebuildField()
        beginStone()
        startTimer()
        bump()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit { timer?.invalidate() }

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.step(dt: 1.0 / 60.0)
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func bump() { frame = frame &+ 1 }

    // MARK: - Queue

    private func refillQueue(store: CBStore) {
        let pool = store.unlockedIDs
        guard !pool.isEmpty else { queue.append(0); return }
        for _ in 0..<14 {
            // Weight the early stones toward broad shapes so a Zen run has a floor.
            let n = queue.count
            var choice: Int
            if n < 2, let wide = pool.filter({ CBShores.shore(of: $0).index == 1 }).randomPick(&rng) {
                choice = wide
            } else {
                choice = pool[rng.int(pool.count)]
            }
            queue.append(choice)
        }
    }

    var currentKindID: Int? {
        guard queueIndex >= 0, queueIndex < queue.count else { return nil }
        return queue[queueIndex]
    }

    var upcoming: [Int] {
        guard queueIndex + 1 < queue.count else { return [] }
        return Array(queue[(queueIndex + 1)..<min(queue.count, queueIndex + 4)])
    }

    var stonesRemaining: Int? {
        switch mode {
        case .trials, .daily: return max(0, queue.count - queueIndex)
        default: return nil
        }
    }

    // MARK: - World geometry

    var baseX: Double { Double(boardSize.width) / 2 }

    var stackTopY: Double {
        var top = CBCatalog.baseTopY
        for s in placed {
            let k = CBCatalog.kind(s.kindID)
            let pts = cbWorldPoints(k.poly, position: s.position, rotation: s.rotation)
            let b = cbBounds(pts)
            top = max(top, b.maxY)
        }
        return top
    }

    var currentHeight: Double { max(0, stackTopY - CBCatalog.baseTopY) }

    func screenPoint(_ w: CGPoint) -> CGPoint {
        CGPoint(x: CGFloat(w.x),
                y: CGFloat(Double(boardSize.height) - groundInset - (Double(w.y) - cameraY)))
    }

    func worldY(fromScreenY y: Double) -> Double {
        cameraY + Double(boardSize.height) - groundInset - y
    }

    /// Rotated half-extent of the stone currently in hand.
    private func heldExtent() -> (maxY: Double, minY: Double, halfW: Double) {
        guard let id = currentKindID else { return (0, 0, 0) }
        let k = CBCatalog.kind(id)
        let pts = cbWorldPoints(k.poly, position: .zero, rotation: holdRot)
        let b = cbBounds(pts)
        return (b.maxY, b.minY, (b.maxX - b.minX) / 2)
    }

    /// The stone waits a fixed distance above the crown of the cairn, but never
    /// higher than the top of the board.
    var holdY: Double {
        let e = heldExtent()
        let ceiling = worldY(fromScreenY: 26) - e.maxY
        let hover = stackTopY + 118 - e.minY
        return min(ceiling, hover)
    }

    var holdPosition: CGPoint { CGPoint(x: holdX, y: holdY) }

    // MARK: - Field

    private func rebuildField() {
        var f = CBHeightField(width: Double(boardSize.width))
        f.add(points: cbWorldPoints(CBCatalog.base, position: CGPoint(x: baseX, y: 0), rotation: 0),
              owner: -2)
        for (i, s) in placed.enumerated() {
            let k = CBCatalog.kind(s.kindID)
            f.add(points: cbWorldPoints(k.poly, position: s.position, rotation: s.rotation), owner: i)
        }
        field = f
    }

    // MARK: - Placement

    private func beginStone() {
        holdRot = 0
        // Start above the current centre of the cairn, not the plinth, so tall
        // stacks do not force a long drag on every stone.
        if let top = placed.last {
            holdX = Double(top.position.x)
        } else {
            holdX = baseX
        }
        clampHold()
        recomputePreview()
    }

    private func clampHold() {
        let e = heldExtent()
        let lo = e.halfW + 6
        let hi = Double(boardSize.width) - e.halfW - 6
        if lo < hi { holdX = min(hi, max(lo, holdX)) } else { holdX = Double(boardSize.width) / 2 }
    }

    func recomputePreview() {
        guard let id = currentKindID, phase == .placing else { preview = nil; return }
        let k = CBCatalog.kind(id)
        var r = CBStatics.settle(kind: k, startPos: holdPosition, rotation: holdRot, field: field)

        if !r.supported {
            r.onCrown = false
            hint = "Nothing below — move over the shore"
        } else {
            // A cairn only grows on its own crown: the seat has to touch the
            // stone that is currently on top (or the plinth for the first one).
            let required = placed.isEmpty ? -2 : placed.count - 1
            r.onCrown = (r.topOwner == required)
            hint = r.onCrown ? "" : (placed.isEmpty
                ? "Start on the plinth"
                : "It has to rest on the crown of the cairn")
        }
        preview = r
    }

    /// Live margin the balance meter shows: the stack's weakest level with the
    /// held stone hypothetically seated where the ghost says it will land.
    func previewLevels() -> [CBLevel] {
        guard let p = preview, p.supported, p.onCrown, let id = currentKindID, phase == .placing else {
            return levels
        }
        var hypothetical = placed
        hypothetical.append(CBPlacedStone(id: placed.count, kindID: id,
                                          position: p.position, rotation: p.rotation,
                                          contactL: p.contactL, contactR: p.contactR,
                                          contactY: p.contactY))
        return CBStability.evaluate(placed: hypothetical, catalog: CBCatalog.stones, windAccel: windAccel)
    }

    func previewMargin() -> Double? {
        guard preview?.supported == true, preview?.onCrown == true, phase == .placing else { return nil }
        return CBStability.weakest(previewLevels())?.margin
    }

    /// Handles an orientation change without losing the cairn: everything keeps
    /// its world pose, shifted so the plinth stays centred under the new width.
    func updateBoard(size: CGSize) {
        let newW = max(240, size.width)
        let newH = max(240, size.height)
        guard abs(newW - boardSize.width) > 0.5 || abs(newH - boardSize.height) > 0.5 else { return }
        let dx = Double(newW - boardSize.width) / 2
        boardSize = CGSize(width: newW, height: newH)
        if dx != 0 {
            for i in placed.indices {
                placed[i].position.x += CGFloat(dx)
                placed[i].contactL += dx
                placed[i].contactR += dx
            }
            for i in lastStable.indices {
                lastStable[i].position.x += CGFloat(dx)
                lastStable[i].contactL += dx
                lastStable[i].contactR += dx
            }
            holdX += dx
        }
        rebuildField()
        clampHold()
        levels = CBStability.evaluate(placed: placed, catalog: CBCatalog.stones, windAccel: windAccel)
        weakest = CBStability.weakest(levels)
        recomputePreview()
        bump()
    }

    func moveHold(toX x: Double) {
        guard phase == .placing else { return }
        holdX = x
        clampHold()
        recomputePreview()
        bump()
    }

    func rotate(byDegrees deg: Double) {
        guard phase == .placing else { return }
        holdRot += deg * Double.pi / 180
        if holdRot > Double.pi { holdRot -= 2 * Double.pi }
        if holdRot < -Double.pi { holdRot += 2 * Double.pi }
        clampHold()
        recomputePreview()
        bump()
    }

    func setRotation(radians: Double, stepDegrees: Int) {
        guard phase == .placing else { return }
        let step = Double(max(1, stepDegrees)) * Double.pi / 180
        let snapped = (radians / step).rounded() * step
        holdRot = snapped
        clampHold()
        recomputePreview()
        bump()
    }

    var holdDegrees: Int {
        var d = Int((holdRot * 180 / Double.pi).rounded())
        while d > 180 { d -= 360 }
        while d <= -180 { d += 360 }
        return d
    }

    func commit(store: CBStore) {
        guard phase == .placing, let p = preview, p.supported, p.onCrown else {
            if hint.isEmpty { hint = "Nothing below — move over the shore" }
            bump()
            return
        }
        settleFrom = (holdPosition, holdRot)
        settleTo = p
        settleT = 0
        phase = .settling
        CBHaptics.tap(store.data.haptics)
        bump()
    }

    private func finishSettle(store: CBStore) {
        guard let p = settleTo, let id = currentKindID else {
            phase = .placing
            return
        }
        let stone = CBPlacedStone(id: placed.count, kindID: id,
                                  position: p.position, rotation: p.rotation,
                                  contactL: p.contactL, contactR: p.contactR,
                                  contactY: p.contactY)
        placed.append(stone)
        rebuildField()
        levels = CBStability.evaluate(placed: placed, catalog: CBCatalog.stones, windAccel: windAccel)
        weakest = CBStability.weakest(levels)
        settleTo = nil

        bestHeightThisRun = max(bestHeightThisRun, currentHeight)

        if let w = weakest, w.margin < 0 {
            store.recordPlacement(kindID: id)
            beginTopple(level: w, store: store)
            return
        }

        minMarginThisRun = min(minMarginThisRun, weakest?.margin ?? 1)
        lastStable = placed
        store.recordPlacement(kindID: id)
        CBHaptics.seat(store.data.haptics)
        pulse = 1
        queueIndex += 1

        if queueIndex >= queue.count {
            switch mode {
            case .zen, .windward:
                refillQueue(store: store)
                phase = .placing
                beginStone()
            case .trials, .daily:
                finishRun(toppled: false, store: store)
                return
            }
        } else if placed.count >= stoneCap {
            finishRun(toppled: false, store: store)
            return
        } else {
            phase = .placing
            beginStone()
        }
        bump()
    }

    private func beginTopple(level: CBLevel, store: CBStore) {
        topple = CBTopple.begin(level: level)
        phase = .toppling
        CBHaptics.fall(store.data.haptics)
        hint = ""
        bump()
    }

    // MARK: - Run completion

    private func finishRun(toppled: Bool, store: CBStore) {
        phase = .over
        // Score by what actually stood: the last fully stable cairn.
        let survivors = toppled ? lastStable.count : placed.count
        let heightAtEnd = toppled ? bestHeightThisRun : currentHeight
        let stones = toppled ? survivors : placed.count
        let minMargin = minMarginThisRun.isFinite ? minMarginThisRun : 0

        var metric: Double = Double(stones)
        var stars = 0
        var passed = false

        if let t = trial, mode == .trials {
            switch t.kind {
            case .height: metric = heightAtEnd
            case .place:  metric = Double(stones)
            case .margin: metric = minMargin * 100
            }
            let placedAll = !toppled && placed.count >= t.stones.count
            stars = t.starsEarned(metric: metric, placedAll: placedAll)
            passed = stars > 0
            store.recordTrial(id: t.id, stars: stars, metric: metric)
        } else if mode == .daily {
            metric = heightAtEnd
            passed = !toppled && placed.count >= queue.count
            store.recordDaily(dayKey: dayKey, height: heightAtEnd, completed: passed)
        } else {
            metric = heightAtEnd
            passed = !toppled
        }

        let priorBest = mode == .zen ? store.data.bestZenHeight
                      : (mode == .windward ? store.data.bestWindwardHeight : 0)
        let newRecord = (mode == .zen || mode == .windward) && heightAtEnd > priorBest && heightAtEnd > 0

        store.recordRunEnd(mode: mode, stones: stones, height: heightAtEnd)

        result = CBRunResult(mode: mode, toppled: toppled, stones: stones,
                             height: heightAtEnd, minMargin: minMargin,
                             metric: metric, stars: stars, passed: passed,
                             trialID: trial?.id, dayKey: mode == .daily ? dayKey : nil,
                             newRecord: newRecord,
                             failedLevel: toppled ? topple?.fromIndex : nil)

        saveSnapshotIfWorthy(store: store, passed: passed, height: heightAtEnd, minMargin: minMargin)
        bump()
    }

    private func saveSnapshotIfWorthy(store: CBStore, passed: Bool, height: Double, minMargin: Double) {
        let stones = lastStable
        guard stones.count >= 3 else { return }
        let worthy: Bool
        switch mode {
        case .zen, .windward: worthy = stones.count >= 3
        case .trials: worthy = passed
        case .daily: worthy = passed
        }
        guard worthy else { return }

        let label: String
        let name: String
        switch mode {
        case .zen:
            label = "Zen run"; name = "Zen cairn, \(stones.count) stones"
        case .windward:
            label = "Windward run"; name = "Windward cairn, \(stones.count) stones"
        case .trials:
            label = trial.map { "Trial \($0.id)" } ?? "Trial"
            name = trial?.name ?? "Trial cairn"
        case .daily:
            label = "Daily " + dayKey
            name = "Daily cairn"
        }

        let snap = CBCairnSnapshot(
            name: name,
            savedAt: Date().timeIntervalSince1970,
            mode: mode.rawValue,
            kindIDs: stones.map { $0.kindID },
            xs: stones.map { Double($0.position.x) },
            ys: stones.map { Double($0.position.y) },
            rots: stones.map { $0.rotation },
            height: height,
            minMargin: minMargin,
            label: label)
        store.addSnapshot(snap)
    }

    /// Ends a Zen / Windward run early from the pause sheet.
    func endRunEarly(store: CBStore) {
        guard phase != .over else { return }
        lastStable = placed
        finishRun(toppled: false, store: store)
    }

    // MARK: - Frame step

    private func step(dt: Double) {
        var needsRedraw = false
        let store = CBStore.shared

        // wind
        if windStrength > 0 {
            windTime += dt
            let seed = mode == .daily ? CBDaily.seed(for: dayKey) : UInt64(abs((trial?.id ?? 3) * 131 + mode.rawValue))
            windAccel = CBWind.accel(t: windTime, seed: seed, strength: windStrength)
            needsRedraw = true
        } else {
            windAccel = 0
        }

        // camera
        let e = heldExtent()
        var clearance = 152.0 + (e.maxY - e.minY)
        clearance = min(clearance, Double(boardSize.height) * 0.58)
        let desired = max(0, stackTopY - (Double(boardSize.height) - groundInset - clearance))
        if abs(desired - cameraY) > 0.3 {
            cameraY += (desired - cameraY) * min(1, dt * 7.5)
            needsRedraw = true
        } else if cameraY != desired {
            cameraY = desired
            needsRedraw = true
        }

        if pulse > 0 {
            pulse = max(0, pulse - dt * 1.6)
            needsRedraw = true
        }

        switch phase {
        case .settling:
            settleT += dt / 0.30
            if settleT >= 1 {
                settleT = 1
                finishSettle(store: store)
            }
            needsRedraw = true

        case .toppling:
            if var t = topple {
                let idx = max(0, min(placed.count, t.fromIndex))
                var mass = 0.0, mx = 0.0, my = 0.0
                if idx < placed.count {
                    for j in idx..<placed.count {
                        let k = CBCatalog.kind(placed[j].kindID)
                        let c = cbWorldCentroid(k.poly, position: placed[j].position, rotation: placed[j].rotation)
                        let rc = cbRotateAbout(c, pivot: t.pivot, angle: t.angle)
                        mass += k.mass
                        mx += k.mass * Double(rc.x)
                        my += k.mass * Double(rc.y)
                    }
                }
                let comX = cbSafeDivide(mx, mass, fallback: Double(t.pivot.x) + 1)
                let comY = cbSafeDivide(my, mass, fallback: Double(t.pivot.y) + 20)
                CBTopple.step(&t, comX: comX, comY: comY, dt: dt)
                topple = t
                if t.finished {
                    finishRun(toppled: true, store: store)
                }
                needsRedraw = true
            } else {
                finishRun(toppled: true, store: store)
                needsRedraw = true
            }

        case .placing:
            // A live wind can push a resting cairn past its margin.
            if windStrength > 0, !placed.isEmpty {
                levels = CBStability.evaluate(placed: placed, catalog: CBCatalog.stones, windAccel: windAccel)
                weakest = CBStability.weakest(levels)
                if let w = weakest, w.margin < 0 {
                    beginTopple(level: w, store: store)
                }
            }

        case .over:
            break
        }

        if needsRedraw { bump() }
    }

    // MARK: - Drawing helpers used by the play view

    /// Pose of the stone in hand right now, accounting for the settle animation.
    func heldPose() -> (pos: CGPoint, rot: Double, alpha: Double)? {
        guard let _ = currentKindID else { return nil }
        switch phase {
        case .placing:
            return (holdPosition, holdRot, 1.0)
        case .settling:
            guard let to = settleTo else { return (holdPosition, holdRot, 1.0) }
            let t = cbClamp(settleT, 0, 1)
            let e = t * t * (3 - 2 * t)
            let px = Double(settleFrom.pos.x) + (Double(to.position.x) - Double(settleFrom.pos.x)) * e
            let py = Double(settleFrom.pos.y) + (Double(to.position.y) - Double(settleFrom.pos.y)) * e
            let pr = settleFrom.rot + (to.rotation - settleFrom.rot) * e
            return (CGPoint(x: px, y: py), pr, 1.0)
        default:
            return nil
        }
    }

    /// Transform applied to a stone during a topple (identity below the failure).
    func toppleTransform(index: Int) -> (pivot: CGPoint, angle: Double, drop: Double, fade: Double)? {
        guard let t = topple, index >= t.fromIndex else { return nil }
        return (t.pivot, t.angle, t.drop, t.fade)
    }
}

private extension Array where Element == Int {
    func randomPick(_ rng: inout CBSeededRandom) -> Int? {
        guard !isEmpty else { return nil }
        return self[rng.int(count)]
    }
}
