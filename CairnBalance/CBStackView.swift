import SwiftUI

// MARK: - Mode select

struct CBStackView: View {
    @ObservedObject var store = CBStore.shared
    @Binding var session: CBSession?

    var body: some View {
        CBScreen {
            CBScreenTitle(title: "Cairn Balance",
                          subtitle: "Stack irregular stones. Keep the centre of mass over the seat.")

            heroCard

            CBSectionHeader(text: "Modes")

            zenCard

            NavigationLink(destination: CBTrialsListView(session: $session)) {
                modeCard(mode: .trials,
                         stat: "\(store.totalStars) / \(CBTrialData.maxStars) stars",
                         detail: "\(store.trialsPassed) of \(CBTrialData.all.count) trials passed",
                         chevron: true)
            }
            .buttonStyle(.plain)

            NavigationLink(destination: CBDailyView(session: $session)) {
                modeCard(mode: .daily,
                         stat: store.dailyIsDone(CBDaily.todayKey()) ? "Today is built" : "Today is open",
                         detail: "Streak \(store.data.dailyStreak) day\(store.data.dailyStreak == 1 ? "" : "s")",
                         chevron: true)
            }
            .buttonStyle(.plain)

            Button(action: { session = CBSession(mode: .windward) }) {
                modeCard(mode: .windward,
                         stat: store.data.bestWindwardHeight > 0
                            ? "Best \(CBFormat.height(store.data.bestWindwardHeight)) pt" : "Not attempted",
                         detail: "Best run \(store.data.bestWindwardStones) stones",
                         chevron: false)
            }
            .buttonStyle(.plain)

            CBSectionHeader(text: "How a cairn fails")
            legendCard
        }
    }

    private var heroCard: some View {
        VStack(spacing: 10) {
            Canvas { ctx, size in
                var c = ctx
                CBRender.drawCairn(&c,
                                   kindIDs: [9, 2, 20, 5, 33, 3],
                                   xs: [0, 2, -6, 4, -2, 1],
                                   ys: [16, 40, 74, 106, 148, 178],
                                   rots: [0, 0.06, -0.05, 0.10, -0.02, 0.04],
                                   in: CGRect(x: 12, y: 8, width: size.width - 24, height: size.height - 16),
                                   withBase: true)
            }
            .frame(height: 168)
            Text("Every release resolves a static equilibrium: the combined centre of mass above each contact, against the width of that contact.")
                .font(CBTheme.label(11.5, .regular))
                .foregroundColor(CBTheme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cbCard(pad: 14)
    }

    private var zenCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                CBIconCairn(size: 26, color: CBTheme.slate)
                VStack(alignment: .leading, spacing: 3) {
                    Text(CBMode.zen.title)
                        .font(CBTheme.displayBold(17))
                        .foregroundColor(CBTheme.ink)
                    Text(CBMode.zen.blurb)
                        .font(CBTheme.label(11.5, .regular))
                        .foregroundColor(CBTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                CBPill(text: store.data.bestZenHeight > 0
                       ? "Best \(CBFormat.height(store.data.bestZenHeight)) pt" : "No runs yet",
                       color: CBTheme.driftwood)
                CBPill(text: "\(store.data.bestZenStones) stones", color: CBTheme.seaglass)
                Spacer(minLength: 0)
            }
            Button(action: {
                store.mutate { $0.zenWind.toggle() }
            }) {
                HStack(spacing: 8) {
                    CBToggleMark(on: store.data.zenWind)
                    Text("Gentle wind")
                        .font(CBTheme.label(12.5, .medium))
                        .foregroundColor(CBTheme.ink)
                    Spacer(minLength: 0)
                    Text(store.data.zenWind ? "on" : "off")
                        .font(CBTheme.mono(11))
                        .foregroundColor(CBTheme.inkFaint)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            CBWideButton(title: "Begin a Zen Cairn") {
                session = CBSession(mode: .zen)
            }
        }
        .cbCard(pad: 14)
    }

    private func modeCard(mode: CBMode, stat: String, detail: String, chevron: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Group {
                switch mode {
                case .trials: CBIconStar(size: 24, filled: true, color: CBTheme.driftwood)
                case .daily: CBIconPlumb(size: 24, color: CBTheme.seaglass)
                default: CBIconWind(size: 24, color: CBTheme.moss)
                }
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(mode.title)
                    .font(CBTheme.displayBold(17))
                    .foregroundColor(CBTheme.ink)
                Text(mode.blurb)
                    .font(CBTheme.label(11.5, .regular))
                    .foregroundColor(CBTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    CBPill(text: stat, color: CBTheme.driftwood)
                    Text(detail)
                        .font(CBTheme.label(10.5, .regular))
                        .foregroundColor(CBTheme.inkFaint)
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
            if chevron {
                CBIconChevron(size: 15, color: CBTheme.inkFaint)
                    .padding(.top, 6)
            }
        }
        .cbCard(pad: 14)
    }

    private var legendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            legendRow(color: CBTheme.seaglass, title: "Support interval",
                      text: "The contact the stones above actually rest on. Wider is safer.")
            legendRow(color: CBTheme.moss, title: "Plumb line",
                      text: "Where the combined centre of mass lands on the ground plane.")
            legendRow(color: CBTheme.rust, title: "Negative margin",
                      text: "The plumb line has left the seat. Torque wins and the level goes.")
        }
        .cbCard(pad: 14)
    }

    private func legendRow(color: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Circle().fill(color).frame(width: 9, height: 9).padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CBTheme.label(12.5, .semibold))
                    .foregroundColor(CBTheme.ink)
                Text(text)
                    .font(CBTheme.label(11, .regular))
                    .foregroundColor(CBTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Custom toggle mark (no system Toggle anywhere in this app)

struct CBToggleMark: View {
    let on: Bool
    var body: some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule()
                .fill(on ? CBTheme.moss.opacity(0.85) : CBTheme.paperDeep)
                .frame(width: 40, height: 22)
            Circle()
                .fill(Color.white)
                .frame(width: 18, height: 18)
                .overlay(Circle().stroke(CBTheme.cardEdge, lineWidth: 0.8))
                .padding(.horizontal, 2)
        }
        .frame(width: 40, height: 22)
    }
}

// MARK: - Trials

struct CBTrialsListView: View {
    @ObservedObject var store = CBStore.shared
    @Binding var session: CBSession?

    private let bandGates = [0, 12, 30, 52]

    var body: some View {
        CBScreen(spacing: 12) {
            CBBackRow()
            CBScreenTitle(title: "Trials",
                          subtitle: "\(store.totalStars) of \(CBTrialData.maxStars) stars earned")

            ForEach(0..<4, id: \.self) { band in
                let unlocked = store.totalStars >= bandGates[band]
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(CBBands.names[band])
                            .font(CBTheme.displayBold(16))
                            .foregroundColor(CBTheme.ink)
                        Spacer()
                        Text("\(bandStars(band))/30")
                            .font(CBTheme.mono(12))
                            .foregroundColor(CBTheme.inkFaint)
                    }
                    Text(CBBands.blurbs[band])
                        .font(CBTheme.label(11, .regular))
                        .foregroundColor(CBTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    if unlocked {
                        VStack(spacing: 0) {
                            ForEach(CBTrialData.band(band)) { t in
                                trialRow(t)
                                if t.id % 10 != 0 {
                                    Rectangle().fill(CBTheme.hairline).frame(height: 1)
                                }
                            }
                        }
                    } else {
                        HStack(spacing: 8) {
                            CBIconLock(size: 15)
                            Text("Earn \(bandGates[band]) stars to open this band")
                                .font(CBTheme.label(11.5, .medium))
                                .foregroundColor(CBTheme.inkFaint)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .cbCard(pad: 14)
            }
        }
    }

    private func bandStars(_ band: Int) -> Int {
        CBTrialData.band(band).reduce(0) { $0 + store.stars(forTrial: $1.id) }
    }

    private func trialRow(_ t: CBTrial) -> some View {
        Button(action: { session = CBSession(mode: .trials, trialID: t.id) }) {
            HStack(spacing: 10) {
                Text("\(t.id)")
                    .font(CBTheme.mono(12))
                    .foregroundColor(CBTheme.inkFaint)
                    .frame(width: 22, alignment: .trailing)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.name)
                        .font(CBTheme.label(13.5, .semibold))
                        .foregroundColor(CBTheme.ink)
                    Text(t.goalText + (t.wind > 0 ? "  ·  wind" : ""))
                        .font(CBTheme.label(10.5, .regular))
                        .foregroundColor(CBTheme.inkSoft)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 3) {
                    CBStarRow(earned: store.stars(forTrial: t.id), size: 11)
                    if store.best(forTrial: t.id) > 0 {
                        Text(t.metricText(store.best(forTrial: t.id)))
                            .font(CBTheme.mono(9.5))
                            .foregroundColor(CBTheme.inkFaint)
                    }
                }
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Daily

struct CBDailyView: View {
    @ObservedObject var store = CBStore.shared
    @Binding var session: CBSession?

    private var todayKey: String { CBDaily.todayKey() }

    var body: some View {
        CBScreen(spacing: 12) {
            CBBackRow()
            CBScreenTitle(title: "Daily Cairn",
                          subtitle: CBFormat.prettyDayFormatter.string(from: Date()))

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    dailyStat("Streak", "\(store.data.dailyStreak)")
                    Rectangle().fill(CBTheme.hairline).frame(width: 1, height: 30)
                    dailyStat("Days built", "\(store.data.dailyDone.count)")
                    Rectangle().fill(CBTheme.hairline).frame(width: 1, height: 30)
                    dailyStat("Today's best", store.dailyBest(todayKey).map { CBFormat.height($0) + " pt" } ?? "—")
                }
                Text(store.dailyIsDone(todayKey)
                     ? "Today's cairn is built. The same twelve stones stay available if you want a taller one."
                     : "Twelve stones, seeded from today's date. Seat every one of them to complete the day.")
                    .font(CBTheme.label(11.5, .regular))
                    .foregroundColor(CBTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                CBWideButton(title: store.dailyIsDone(todayKey) ? "Build It Again" : "Build Today's Cairn",
                             tone: CBTheme.seaglass) {
                    session = CBSession(mode: .daily, dayKey: todayKey)
                }
            }
            .cbCard(pad: 14)

            CBSectionHeader(text: "Today's stones")
            VStack(alignment: .leading, spacing: 8) {
                let ids = CBDaily.stones(for: todayKey)
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(0..<4, id: \.self) { col in
                            let i = row * 4 + col
                            if i < ids.count {
                                VStack(spacing: 2) {
                                    CBStonePortrait(kindID: ids[i], boxSize: CGSize(width: 58, height: 40))
                                    Text(CBCatalog.kind(ids[i]).name)
                                        .font(CBTheme.label(8, .medium))
                                        .foregroundColor(CBTheme.inkFaint)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
            .cbCard(pad: 12)

            CBSectionHeader(text: "Last 30 days")
            VStack(alignment: .leading, spacing: 8) {
                CBDailyRibbon()
                    .frame(height: 62)
                HStack(spacing: 12) {
                    ribbonKey(color: CBTheme.moss, text: "built")
                    ribbonKey(color: CBTheme.driftwood.opacity(0.55), text: "attempted")
                    ribbonKey(color: CBTheme.paperDeep, text: "missed")
                }
            }
            .cbCard(pad: 12)
        }
    }

    private func dailyStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(CBTheme.monoBold(15))
                .foregroundColor(CBTheme.ink)
            Text(label)
                .font(CBTheme.label(9.5, .medium))
                .foregroundColor(CBTheme.inkFaint)
        }
        .frame(maxWidth: .infinity)
    }

    private func ribbonKey(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(text)
                .font(CBTheme.label(10, .regular))
                .foregroundColor(CBTheme.inkFaint)
        }
    }
}

/// Thirty-day history ribbon drawn on Canvas.
struct CBDailyRibbon: View {
    @ObservedObject var store = CBStore.shared

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            Canvas { ctx, _ in
                let days = CBDaily.lastDays(30)
                let gap: CGFloat = 2.5
                let cw = max(3, (size.width - gap * 29) / 30)
                let maxBest = max(60.0, store.data.dailyBestValues.max() ?? 60)
                for (i, key) in days.enumerated() {
                    let x = CGFloat(i) * (cw + gap)
                    let done = store.dailyIsDone(key)
                    let best = store.dailyBest(key)
                    let baseRect = CGRect(x: x, y: size.height - 12, width: cw, height: 10)
                    let color: Color = done ? CBTheme.moss
                        : (best != nil ? CBTheme.driftwood.opacity(0.55) : CBTheme.paperDeep)
                    ctx.fill(Path(roundedRect: baseRect, cornerRadius: 2), with: .color(color))
                    if let b = best, b > 0 {
                        let h = CGFloat(cbClamp(b / maxBest, 0.06, 1)) * (size.height - 18)
                        let r = CGRect(x: x, y: size.height - 14 - h, width: cw, height: h)
                        ctx.fill(Path(roundedRect: r, cornerRadius: 1.5),
                                 with: .color(color.opacity(0.55)))
                    }
                }
                let label = Text("30 days")
                    .font(CBTheme.label(9, .medium))
                    .foregroundColor(CBTheme.inkFaint)
                ctx.draw(label, at: CGPoint(x: size.width - 22, y: 6))
            }
            .frame(width: size.width, height: size.height)
        }
    }
}
