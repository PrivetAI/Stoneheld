import SwiftUI

struct SHSession: Identifiable, Equatable {
    let id: UUID
    var mode: SHMode
    var trialID: Int?
    var dayKey: String?

    init(mode: SHMode, trialID: Int? = nil, dayKey: String? = nil) {
        self.id = UUID()
        self.mode = mode
        self.trialID = trialID
        self.dayKey = dayKey
    }

    static func == (a: SHSession, b: SHSession) -> Bool { a.id == b.id }
}

// MARK: - Play screen

struct SHPlayView: View {
    let session: SHSession
    var onExit: () -> Void
    var onReplace: (SHSession) -> Void

    @ObservedObject var store = SHStore.shared
    @StateObject private var engine = SHEngine()

    @State private var started = false
    @State private var showPause = false
    @State private var grabOffset: Double = 0
    @State private var grabbed = false
    @State private var dragMoved = false
    @State private var ringBase: Double = 0
    @State private var ringAccum: Double = 0
    @State private var ringActive = false
    @State private var rotateBase: Double? = nil

    private var trial: SHTrial? {
        session.trialID.flatMap { SHTrialData.trial($0) }
    }

    @State private var compact = false
    @State private var suppressCommit = false

    private var controlHeight: CGFloat { compact ? 82 : (SHSafe.isShort ? 96 : 108) }

    var body: some View {
        GeometryReader { outer in
            ZStack(alignment: .top) {
                SHBackground().equatable()

                VStack(spacing: 0) {
                    header
                        .padding(.top, SHSafe.top + (compact ? 2 : 4))
                        .padding(.horizontal, 14)
                        .padding(.bottom, compact ? 3 : 6)

                    GeometryReader { geo in
                        boardCanvas(size: geo.size)
                            .onAppear {
                                if !started {
                                    started = true
                                    engine.start(mode: session.mode, trial: trial,
                                                 dayKey: session.dayKey ?? SHDaily.todayKey(),
                                                 boardSize: geo.size, store: store)
                                } else {
                                    engine.updateBoard(size: geo.size)
                                }
                            }
                    }
                    .frame(minHeight: compact ? 120 : 220)

                    controlBar
                        .frame(height: controlHeight)
                        .padding(.horizontal, 14)
                        .padding(.bottom, max(compact ? 4 : 6, SHSafe.bottom * 0.5))
                }

                if !engine.hint.isEmpty && engine.phase == .placing && !showPause {
                    Text(engine.hint)
                        .font(SHTheme.label(12, .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(SHTheme.rust.opacity(0.92)))
                        .padding(.top, SHSafe.top + (compact ? 44 : 62))
                }

                SHStatusStrip()

                if showPause { pauseOverlay }
                if let r = engine.result { resultOverlay(r) }
            }
            .frame(width: outer.size.width, height: outer.size.height)
            .onAppear { compact = outer.size.height < 540 }
            .onChange(of: outer.size.height) { h in compact = h < 540 }
        }
        .onDisappear { engine.stop() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 7) {
            HStack(spacing: 10) {
                Button(action: { showPause = true }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(SHTheme.card)
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(SHTheme.cardEdge, lineWidth: 1))
                        HStack(spacing: 3) {
                            Capsule().fill(SHTheme.slate).frame(width: 3, height: 13)
                            Capsule().fill(SHTheme.slate).frame(width: 3, height: 13)
                        }
                    }
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    Text(titleText)
                        .font(SHTheme.displayBold(16))
                        .foregroundColor(SHTheme.ink)
                        .lineLimit(1)
                    Text(subtitleText)
                        .font(SHTheme.label(10.5, .regular))
                        .foregroundColor(SHTheme.inkSoft)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)

                statBlock(value: SHFormat.height(engine.currentHeight), unit: "pt")
                statBlock(value: "\(engine.placed.count)", unit: engine.stonesRemaining.map { "/\(engine.placed.count + $0)" } ?? "stones")
            }

            if store.data.showMeter {
                balanceMeter
            }
            if engine.windStrength > 0 && !compact {
                windGauge
            }
        }
    }

    private func statBlock(value: String, unit: String) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(value)
                .font(SHTheme.monoBold(16))
                .foregroundColor(SHTheme.ink)
            Text(unit)
                .font(SHTheme.label(9, .medium))
                .foregroundColor(SHTheme.inkFaint)
        }
        .frame(minWidth: 40, alignment: .trailing)
    }

    private var titleText: String {
        switch session.mode {
        case .trials: return trial.map { "\($0.id). \($0.name)" } ?? "Trial"
        case .daily: return "Daily Cairn"
        default: return session.mode.title
        }
    }

    private var subtitleText: String {
        switch session.mode {
        case .trials: return trial?.goalText ?? ""
        case .daily: return SHFormat.prettyDayFormatter.string(from: Date())
        case .zen: return store.data.zenWind ? "Gentle wind on" : "No wind, no clock"
        case .windward: return "Lateral force on every centre of mass"
        }
    }

    private var currentMargin: Double? {
        if engine.phase == .placing { return engine.previewMargin() }
        return engine.weakest?.margin
    }

    private var balanceMeter: some View {
        let m = currentMargin
        return VStack(spacing: 3) {
            GeometryReader { geo in
                let w = geo.size.width
                let v = m ?? 0
                let frac = CGFloat(cbClamp((v + 1) / 2, 0, 1))
                ZStack(alignment: .leading) {
                    Capsule().fill(SHTheme.paperDeep)
                    Capsule()
                        .fill(SHTheme.marginColor(v))
                        .frame(width: m == nil ? 0 : max(4, w * frac))
                    Rectangle()
                        .fill(SHTheme.ink.opacity(0.30))
                        .frame(width: 1.5)
                        .offset(x: w * 0.5)
                }
            }
            .frame(height: 7)
            HStack {
                Text("Balance margin")
                    .font(SHTheme.label(9.5, .medium))
                    .foregroundColor(SHTheme.inkFaint)
                Spacer()
                Text(m == nil ? "—" : SHFormat.margin(m ?? 0))
                    .font(SHTheme.mono(10))
                    .foregroundColor(SHTheme.marginColor(m ?? 0))
            }
        }
    }

    private var windGauge: some View {
        HStack(spacing: 8) {
            SHIconWind(size: 16, color: SHTheme.seaglass)
            GeometryReader { geo in
                let w = geo.size.width
                let a = cbClamp(engine.windAccel / max(0.0001, engine.windStrength), -1, 1)
                ZStack(alignment: .center) {
                    Capsule().fill(SHTheme.paperDeep)
                    Rectangle().fill(SHTheme.ink.opacity(0.25)).frame(width: 1.5)
                    Capsule()
                        .fill(SHTheme.seaglass)
                        .frame(width: max(3, CGFloat(abs(a)) * w * 0.5), height: 6)
                        .offset(x: CGFloat(a) * w * 0.25)
                }
            }
            .frame(height: 6)
            Text(windLabel)
                .font(SHTheme.mono(9.5))
                .foregroundColor(SHTheme.inkSoft)
                .frame(width: 52, alignment: .trailing)
        }
    }

    private var windLabel: String {
        let a = engine.windAccel
        if abs(a) < 0.006 { return "calm" }
        return (a > 0 ? "east " : "west ") + String(format: "%.0f", abs(a) * 1000)
    }

    // MARK: - Board

    private func boardCanvas(size: CGSize) -> some View {
        Canvas { ctx, _ in
            drawBoard(&ctx, size: size)
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .gesture(boardDrag(size: size))
        .simultaneousGesture(twoFingerRotation)
    }

    private func boardDrag(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                guard engine.phase == .placing else { return }
                if !grabbed {
                    grabbed = true
                    dragMoved = false
                    grabOffset = 0
                    if let id = engine.currentKindID, let pose = engine.heldPose() {
                        let k = SHCatalog.kind(id)
                        let world = cbWorldPoints(k.poly, position: pose.pos, rotation: pose.rot)
                        let screenPts = world.map { engine.screenPoint($0) }
                        if cbPointInConvex(screenPts, v.startLocation) {
                            grabOffset = engine.holdX - Double(v.startLocation.x)
                        }
                    }
                }
                if abs(v.translation.width) > 4 || abs(v.translation.height) > 4 { dragMoved = true }
                engine.moveHold(toX: Double(v.location.x) + grabOffset)
            }
            .onEnded { v in
                let moved = dragMoved || abs(v.translation.width) > 6
                grabbed = false
                dragMoved = false
                if suppressCommit {
                    suppressCommit = false
                    return
                }
                guard engine.phase == .placing else { return }
                if moved {
                    engine.commit(store: store)
                }
            }
    }

    private var twoFingerRotation: some Gesture {
        RotationGesture(minimumAngleDelta: .degrees(2))
            .onChanged { angle in
                guard engine.phase == .placing else { return }
                suppressCommit = true
                if rotateBase == nil { rotateBase = engine.holdRot }
                let base = rotateBase ?? engine.holdRot
                engine.setRotation(radians: base - angle.radians,
                                   stepDegrees: store.data.rotationStep)
            }
            .onEnded { _ in rotateBase = nil }
    }

    private func drawBoard(_ ctx: inout GraphicsContext, size: CGSize) {
        // Sky wash and waterline, drawn from the passed-in parent size.
        let sky = Path(CGRect(origin: .zero, size: size))
        ctx.fill(sky, with: .linearGradient(
            Gradient(colors: [SHTheme.fog.opacity(0.55), SHTheme.paper.opacity(0.0)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height * 0.72)))

        let groundY = size.height - CGFloat(engine.groundInset) + CGFloat(engine.cameraY)
        if groundY < size.height + 40 {
            var shore = Path()
            shore.move(to: CGPoint(x: 0, y: min(size.height, groundY + 6)))
            shore.addLine(to: CGPoint(x: size.width, y: min(size.height, groundY + 2)))
            shore.addLine(to: CGPoint(x: size.width, y: size.height))
            shore.addLine(to: CGPoint(x: 0, y: size.height))
            shore.closeSubpath()
            ctx.fill(shore, with: .color(SHTheme.driftwood.opacity(0.20)))
        }

        // Plinth
        SHRender.drawBase(&ctx, map: { local in
            engine.screenPoint(CGPoint(x: engine.baseX + Double(local.x), y: Double(local.y)))
        }, scale: 1)

        // Placed stones, with the topple transform applied above the failure line
        for (i, s) in engine.placed.enumerated() {
            let k = SHCatalog.kind(s.kindID)
            let t = engine.toppleTransform(index: i)
            let c = cos(s.rotation), sn = sin(s.rotation)
            let alpha = t?.fade ?? 1
            SHRender.drawStone(&ctx, kind: k, map: { local in
                let wx = Double(s.position.x) + Double(local.x) * c - Double(local.y) * sn
                let wy = Double(s.position.y) + Double(local.x) * sn + Double(local.y) * c
                var p = CGPoint(x: wx, y: wy)
                if let t = t {
                    p = cbRotateAbout(p, pivot: t.pivot, angle: t.angle)
                    p.y -= CGFloat(t.drop)
                }
                return engine.screenPoint(p)
            }, scale: 1, opacity: alpha)
        }

        guard engine.phase == .placing || engine.phase == .settling else { return }

        let lv = engine.previewLevels()
        let weak = SHStability.weakest(lv)

        // Support interval of the level that is closest to going
        if store.data.showSupport, let w = weak, w.seatWidth >= 0 {
            let a = engine.screenPoint(CGPoint(x: w.xL, y: w.y))
            let b = engine.screenPoint(CGPoint(x: w.xR, y: w.y))
            var seat = Path()
            seat.move(to: CGPoint(x: a.x, y: a.y))
            seat.addLine(to: CGPoint(x: max(b.x, a.x + 2), y: b.y))
            ctx.stroke(seat, with: .color(SHTheme.seaglass.opacity(0.95)),
                       style: StrokeStyle(lineWidth: 4, lineCap: .round))
            for x in [w.xL, w.xR] {
                let p = engine.screenPoint(CGPoint(x: x, y: w.y))
                var tick = Path()
                tick.move(to: CGPoint(x: p.x, y: p.y - 7))
                tick.addLine(to: CGPoint(x: p.x, y: p.y + 7))
                ctx.stroke(tick, with: .color(SHTheme.seaglass), lineWidth: 1.6)
            }
        }

        // Plumb line from the combined centre of mass down to that contact
        if store.data.showPlumb, let w = weak {
            let top = engine.screenPoint(CGPoint(x: w.effectiveComX, y: w.comY))
            let bottom = engine.screenPoint(CGPoint(x: w.effectiveComX, y: w.y))
            var line = Path()
            line.move(to: top)
            line.addLine(to: bottom)
            let col = SHTheme.marginColor(w.margin)
            ctx.stroke(line, with: .color(col.opacity(0.9)),
                       style: StrokeStyle(lineWidth: 1.6, dash: [5, 4]))
            let r: CGFloat = 5
            ctx.fill(Path(ellipseIn: CGRect(x: top.x - r, y: top.y - r, width: r * 2, height: r * 2)),
                     with: .color(col))
            ctx.stroke(Path(ellipseIn: CGRect(x: top.x - r - 3, y: top.y - r - 3,
                                              width: r * 2 + 6, height: r * 2 + 6)),
                       with: .color(col.opacity(0.45)), lineWidth: 1)
            var bob = Path()
            bob.move(to: CGPoint(x: bottom.x, y: bottom.y + 9))
            bob.addLine(to: CGPoint(x: bottom.x - 5, y: bottom.y))
            bob.addLine(to: CGPoint(x: bottom.x + 5, y: bottom.y))
            bob.closeSubpath()
            ctx.fill(bob, with: .color(col))
        }

        // Ghost of where the stone will seat
        if engine.phase == .placing, let id = engine.currentKindID,
           let p = engine.preview, p.supported {
            let k = SHCatalog.kind(id)
            let c = cos(p.rotation), sn = sin(p.rotation)
            let ghostPath = SHRender.path(k, map: { local in
                let wx = Double(p.position.x) + Double(local.x) * c - Double(local.y) * sn
                let wy = Double(p.position.y) + Double(local.x) * sn + Double(local.y) * c
                return engine.screenPoint(CGPoint(x: wx, y: wy))
            })
            ctx.stroke(ghostPath,
                       with: .color(p.onCrown ? SHTheme.slate.opacity(0.55) : SHTheme.rust.opacity(0.7)),
                       style: StrokeStyle(lineWidth: 1.4, dash: [5, 4]))
        }

        // The stone in hand, plus a drop guide
        if let pose = engine.heldPose(), let id = engine.currentKindID {
            let k = SHCatalog.kind(id)
            if engine.phase == .placing, let p = engine.preview, p.supported, p.onCrown {
                let a = engine.screenPoint(CGPoint(x: Double(pose.pos.x), y: Double(pose.pos.y)))
                let b = engine.screenPoint(CGPoint(x: Double(p.position.x), y: Double(p.position.y)))
                var guideLine = Path()
                guideLine.move(to: a)
                guideLine.addLine(to: b)
                ctx.stroke(guideLine, with: .color(SHTheme.slate.opacity(0.22)),
                           style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
            }
            let c = cos(pose.rot), sn = sin(pose.rot)
            SHRender.drawStone(&ctx, kind: k, map: { local in
                let wx = Double(pose.pos.x) + Double(local.x) * c - Double(local.y) * sn
                let wy = Double(pose.pos.y) + Double(local.x) * sn + Double(local.y) * c
                return engine.screenPoint(CGPoint(x: wx, y: wy))
            }, scale: 1, opacity: pose.alpha, outline: SHTheme.ink.opacity(0.55))
        }

        // Seat confirmation pulse
        if engine.pulse > 0, let last = engine.placed.last {
            let p = engine.screenPoint(CGPoint(x: (last.contactL + last.contactR) / 2, y: last.contactY))
            let r = CGFloat(10 + (1 - engine.pulse) * 26)
            ctx.stroke(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r * 0.45,
                                              width: r * 2, height: r * 0.9)),
                       with: .color(SHTheme.moss.opacity(engine.pulse * 0.55)), lineWidth: 2)
        }
    }

    // MARK: - Controls

    private var controlBar: some View {
        HStack(spacing: 10) {
            if !store.data.controlOnRight { twistRing }
            VStack(spacing: 7) {
                HStack(spacing: 6) {
                    stepButton(plus: false)
                    Text("\(engine.holdDegrees)°")
                        .font(SHTheme.monoBold(14))
                        .foregroundColor(SHTheme.ink)
                        .frame(minWidth: 52)
                    stepButton(plus: true)
                }
                SHWideButton(title: "Set Stone", tone: SHTheme.slate,
                             enabled: engine.phase == .placing && engine.preview?.supported == true
                                      && engine.preview?.onCrown == true) {
                    engine.commit(store: store)
                }
            }
            .frame(maxWidth: .infinity)
            nextStones
            if store.data.controlOnRight { twistRing }
        }
    }

    private func stepButton(plus: Bool) -> some View {
        Button(action: {
            engine.rotate(byDegrees: (plus ? 1 : -1) * Double(store.data.rotationStep))
            SHHaptics.tap(store.data.haptics)
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(SHTheme.card)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(SHTheme.cardEdge, lineWidth: 1))
                SHIconStep(size: 15, color: SHTheme.slate, plus: plus)
            }
            .frame(width: 34, height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(engine.phase != .placing)
    }

    private var ringSize: CGFloat { compact ? 66 : (SHSafe.isShort ? 74 : 84) }

    private var twistRing: some View {
        ZStack {
            Circle().fill(SHTheme.card)
            Circle().stroke(SHTheme.cardEdge, lineWidth: 1)
            Canvas { ctx, s in
                let c = CGPoint(x: s.width / 2, y: s.height / 2)
                let r = min(s.width, s.height) / 2 - 6
                for i in 0..<24 {
                    let a = Double(i) / 24 * 2 * Double.pi
                    let long = i % 6 == 0
                    let inner = r - (long ? 9 : 5)
                    var p = Path()
                    p.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * inner, y: c.y + CGFloat(sin(a)) * inner))
                    p.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r))
                    ctx.stroke(p, with: .color(SHTheme.inkFaint.opacity(long ? 0.9 : 0.5)), lineWidth: long ? 1.6 : 1)
                }
                let a = -Double(engine.holdRot) - Double.pi / 2
                var needle = Path()
                needle.move(to: c)
                needle.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * (r - 4), y: c.y + CGFloat(sin(a)) * (r - 4)))
                ctx.stroke(needle, with: .color(ringActive ? SHTheme.seaglass : SHTheme.slate),
                           style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)),
                         with: .color(SHTheme.slate))
            }
            .padding(2)
            SHIconTwist(size: ringSize * 0.30, color: SHTheme.inkFaint.opacity(0.55))
                .offset(y: ringSize * 0.26)
        }
        .frame(width: ringSize, height: ringSize)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    guard engine.phase == .placing else { return }
                    let c = CGPoint(x: ringSize / 2, y: ringSize / 2)
                    let a = atan2(Double(v.location.y - c.y), Double(v.location.x - c.x))
                    if !ringActive {
                        ringActive = true
                        ringBase = engine.holdRot
                        ringAccum = 0
                        lastRingAngle = a
                    }
                    var d = a - lastRingAngle
                    while d > Double.pi { d -= 2 * Double.pi }
                    while d < -Double.pi { d += 2 * Double.pi }
                    lastRingAngle = a
                    ringAccum += d
                    engine.setRotation(radians: ringBase - ringAccum,
                                       stepDegrees: store.data.rotationStep)
                }
                .onEnded { _ in
                    ringActive = false
                    SHHaptics.tap(store.data.haptics)
                }
        )
    }

    @State private var lastRingAngle: Double = 0

    private var nextStones: some View {
        VStack(spacing: 3) {
            Text("NEXT")
                .font(SHTheme.label(8, .semibold))
                .tracking(1)
                .foregroundColor(SHTheme.inkFaint)
            ForEach(Array(engine.upcoming.prefix(compact ? 2 : 3).enumerated()), id: \.offset) { item in
                SHStonePortrait(kindID: item.element, boxSize: CGSize(width: 40, height: 20))
            }
            if engine.upcoming.isEmpty {
                Text("last")
                    .font(SHTheme.label(9, .regular))
                    .foregroundColor(SHTheme.inkFaint)
            }
        }
        .frame(width: 44)
    }

    // MARK: - Pause

    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { showPause = false }
            VStack(spacing: 12) {
                Text("Paused")
                    .font(SHTheme.displayBold(21))
                    .foregroundColor(SHTheme.ink)
                Text(pauseStats)
                    .font(SHTheme.label(12, .regular))
                    .foregroundColor(SHTheme.inkSoft)
                    .multilineTextAlignment(.center)
                SHWideButton(title: "Resume") { showPause = false }
                SHGhostButton(title: "Restart") {
                    showPause = false
                    onReplace(SHSession(mode: session.mode, trialID: session.trialID, dayKey: session.dayKey))
                }
                if session.mode == .zen || session.mode == .windward {
                    SHGhostButton(title: "Finish Run Here", tone: SHTheme.moss) {
                        showPause = false
                        engine.endRunEarly(store: store)
                    }
                }
                SHGhostButton(title: "Leave", tone: SHTheme.rust) {
                    engine.stop()
                    onExit()
                }
            }
            .cbCard(pad: 18)
            .frame(maxWidth: 300)
            .padding(.horizontal, 28)
        }
    }

    private var pauseStats: String {
        "\(engine.placed.count) stones seated  ·  \(SHFormat.height(engine.currentHeight)) pt tall"
    }

    // MARK: - Result

    private func resultOverlay(_ r: SHRunResult) -> some View {
        ZStack {
            Color.black.opacity(0.42).ignoresSafeArea()
            VStack(spacing: 11) {
                Text(resultTitle(r))
                    .font(SHTheme.displayBold(22))
                    .foregroundColor(r.toppled ? SHTheme.rust : SHTheme.ink)
                Text(resultBlurb(r))
                    .font(SHTheme.label(12, .regular))
                    .foregroundColor(SHTheme.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if session.mode == .trials {
                    SHStarRow(earned: r.stars, size: 22)
                        .padding(.vertical, 2)
                }

                HStack(spacing: 0) {
                    resultStat("Stones", "\(r.stones)")
                    Rectangle().fill(SHTheme.hairline).frame(width: 1, height: 26)
                    resultStat("Height", SHFormat.height(r.height) + " pt")
                    Rectangle().fill(SHTheme.hairline).frame(width: 1, height: 26)
                    resultStat("Min margin", r.stones > 0 ? SHFormat.margin(r.minMargin) : "—")
                }
                .padding(.vertical, 4)

                if r.newRecord {
                    SHPill(text: "New personal best", color: SHTheme.moss)
                }

                SHWideButton(title: "Try Again") {
                    onReplace(SHSession(mode: session.mode, trialID: session.trialID, dayKey: session.dayKey))
                }
                if session.mode == .trials, let t = trial, let next = SHTrialData.trial(t.id + 1), r.passed {
                    SHGhostButton(title: "Next: \(next.name)", tone: SHTheme.seaglass) {
                        onReplace(SHSession(mode: .trials, trialID: next.id))
                    }
                }
                SHGhostButton(title: "Back to Modes", tone: SHTheme.slate) {
                    engine.stop()
                    onExit()
                }
            }
            .cbCard(pad: 18)
            .frame(maxWidth: 320)
            .padding(.horizontal, 24)
        }
    }

    private func resultStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(SHTheme.monoBold(14))
                .foregroundColor(SHTheme.ink)
            Text(label)
                .font(SHTheme.label(9, .medium))
                .foregroundColor(SHTheme.inkFaint)
        }
        .frame(maxWidth: .infinity)
    }

    private func resultTitle(_ r: SHRunResult) -> String {
        if r.toppled { return "The Cairn Went" }
        switch session.mode {
        case .trials: return r.passed ? "Trial Complete" : "Not Quite"
        case .daily: return r.passed ? "Daily Cairn Built" : "Run Ended"
        default: return "Run Ended"
        }
    }

    private func resultBlurb(_ r: SHRunResult) -> String {
        if r.toppled {
            let lvl = (r.failedLevel ?? 0) + 1
            return "Torque won at level \(lvl). The combined centre of mass above that contact left its support interval."
        }
        switch session.mode {
        case .trials:
            guard let t = trial else { return "Run finished." }
            return "\(t.metricLabel): \(t.metricText(r.metric))  ·  target \(t.metricText(t.passBar))"
        case .daily:
            return r.passed ? "All \(r.stones) stones seated. Come back tomorrow for a new set."
                            : "Seat every stone in the set to complete the day."
        case .zen:
            return "You finished standing. The cairn is saved to your gallery."
        case .windward:
            return "You held it against the wind. Saved to your gallery."
        }
    }
}
