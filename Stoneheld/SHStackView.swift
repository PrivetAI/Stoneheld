import SwiftUI

// MARK: - Mode select

struct SHStackView: View {
    @ObservedObject var store = SHStore.shared
    @Binding var session: SHSession?

    var body: some View {
        SHScreen {
            SHScreenTitle(title: "Stoneheld",
                          subtitle: "Stack irregular stones. Keep the centre of mass over the seat.")

            heroCard

            SHSectionHeader(text: "Modes")

            zenCard

            NavigationLink(destination: SHTrialsListView(session: $session)) {
                modeCard(mode: .trials,
                         stat: "\(store.totalStars) / \(SHTrialData.maxStars) stars",
                         detail: "\(store.trialsPassed) of \(SHTrialData.all.count) trials passed",
                         chevron: true)
            }
            .buttonStyle(.plain)

            NavigationLink(destination: SHDailyView(session: $session)) {
                modeCard(mode: .daily,
                         stat: store.dailyIsDone(SHDaily.todayKey()) ? "Today is built" : "Today is open",
                         detail: "Streak \(store.data.dailyStreak) day\(store.data.dailyStreak == 1 ? "" : "s")",
                         chevron: true)
            }
            .buttonStyle(.plain)

            Button(action: { session = SHSession(mode: .windward) }) {
                modeCard(mode: .windward,
                         stat: store.data.bestWindwardHeight > 0
                            ? "Best \(SHFormat.height(store.data.bestWindwardHeight)) pt" : "Not attempted",
                         detail: "Best run \(store.data.bestWindwardStones) stones",
                         chevron: false)
            }
            .buttonStyle(.plain)

            SHSectionHeader(text: "How a cairn fails")
            legendCard
        }
    }

    private var heroCard: some View {
        VStack(spacing: 10) {
            Canvas { ctx, size in
                var c = ctx
                SHRender.drawCairn(&c,
                                   kindIDs: [9, 2, 20, 5, 33, 3],
                                   xs: [0, 2, -6, 4, -2, 1],
                                   ys: [16, 40, 74, 106, 148, 178],
                                   rots: [0, 0.06, -0.05, 0.10, -0.02, 0.04],
                                   in: CGRect(x: 12, y: 8, width: size.width - 24, height: size.height - 16),
                                   withBase: true)
            }
            .frame(height: 168)
            Text("Every release resolves a static equilibrium: the combined centre of mass above each contact, against the width of that contact.")
                .font(SHTheme.label(11.5, .regular))
                .foregroundColor(SHTheme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cbCard(pad: 14)
    }

    private var zenCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                SHIconCairn(size: 26, color: SHTheme.slate)
                VStack(alignment: .leading, spacing: 3) {
                    Text(SHMode.zen.title)
                        .font(SHTheme.displayBold(17))
                        .foregroundColor(SHTheme.ink)
                    Text(SHMode.zen.blurb)
                        .font(SHTheme.label(11.5, .regular))
                        .foregroundColor(SHTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                SHPill(text: store.data.bestZenHeight > 0
                       ? "Best \(SHFormat.height(store.data.bestZenHeight)) pt" : "No runs yet",
                       color: SHTheme.driftwood)
                SHPill(text: "\(store.data.bestZenStones) stones", color: SHTheme.seaglass)
                Spacer(minLength: 0)
            }
            Button(action: {
                store.mutate { $0.zenWind.toggle() }
            }) {
                HStack(spacing: 8) {
                    SHToggleMark(on: store.data.zenWind)
                    Text("Gentle wind")
                        .font(SHTheme.label(12.5, .medium))
                        .foregroundColor(SHTheme.ink)
                    Spacer(minLength: 0)
                    Text(store.data.zenWind ? "on" : "off")
                        .font(SHTheme.mono(11))
                        .foregroundColor(SHTheme.inkFaint)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            SHWideButton(title: "Begin a Zen Cairn") {
                session = SHSession(mode: .zen)
            }
        }
        .cbCard(pad: 14)
    }

    private func modeCard(mode: SHMode, stat: String, detail: String, chevron: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Group {
                switch mode {
                case .trials: SHIconStar(size: 24, filled: true, color: SHTheme.driftwood)
                case .daily: SHIconPlumb(size: 24, color: SHTheme.seaglass)
                default: SHIconWind(size: 24, color: SHTheme.moss)
                }
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(mode.title)
                    .font(SHTheme.displayBold(17))
                    .foregroundColor(SHTheme.ink)
                Text(mode.blurb)
                    .font(SHTheme.label(11.5, .regular))
                    .foregroundColor(SHTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    SHPill(text: stat, color: SHTheme.driftwood)
                    Text(detail)
                        .font(SHTheme.label(10.5, .regular))
                        .foregroundColor(SHTheme.inkFaint)
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
            if chevron {
                SHIconChevron(size: 15, color: SHTheme.inkFaint)
                    .padding(.top, 6)
            }
        }
        .cbCard(pad: 14)
    }

    private var legendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            legendRow(color: SHTheme.seaglass, title: "Support interval",
                      text: "The contact the stones above actually rest on. Wider is safer.")
            legendRow(color: SHTheme.moss, title: "Plumb line",
                      text: "Where the combined centre of mass lands on the ground plane.")
            legendRow(color: SHTheme.rust, title: "Negative margin",
                      text: "The plumb line has left the seat. Torque wins and the level goes.")
        }
        .cbCard(pad: 14)
    }

    private func legendRow(color: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Circle().fill(color).frame(width: 9, height: 9).padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SHTheme.label(12.5, .semibold))
                    .foregroundColor(SHTheme.ink)
                Text(text)
                    .font(SHTheme.label(11, .regular))
                    .foregroundColor(SHTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Custom toggle mark (no system Toggle anywhere in this app)

struct SHToggleMark: View {
    let on: Bool
    var body: some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule()
                .fill(on ? SHTheme.moss.opacity(0.85) : SHTheme.paperDeep)
                .frame(width: 40, height: 22)
            Circle()
                .fill(Color.white)
                .frame(width: 18, height: 18)
                .overlay(Circle().stroke(SHTheme.cardEdge, lineWidth: 0.8))
                .padding(.horizontal, 2)
        }
        .frame(width: 40, height: 22)
    }
}

// MARK: - Trials

struct SHTrialsListView: View {
    @ObservedObject var store = SHStore.shared
    @Binding var session: SHSession?

    private let bandGates = [0, 12, 30, 52]

    var body: some View {
        SHScreen(spacing: 12) {
            SHBackRow()
            SHScreenTitle(title: "Trials",
                          subtitle: "\(store.totalStars) of \(SHTrialData.maxStars) stars earned")

            ForEach(0..<4, id: \.self) { band in
                let unlocked = store.totalStars >= bandGates[band]
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(SHBands.names[band])
                            .font(SHTheme.displayBold(16))
                            .foregroundColor(SHTheme.ink)
                        Spacer()
                        Text("\(bandStars(band))/30")
                            .font(SHTheme.mono(12))
                            .foregroundColor(SHTheme.inkFaint)
                    }
                    Text(SHBands.blurbs[band])
                        .font(SHTheme.label(11, .regular))
                        .foregroundColor(SHTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    if unlocked {
                        VStack(spacing: 0) {
                            ForEach(SHTrialData.band(band)) { t in
                                trialRow(t)
                                if t.id % 10 != 0 {
                                    Rectangle().fill(SHTheme.hairline).frame(height: 1)
                                }
                            }
                        }
                    } else {
                        HStack(spacing: 8) {
                            SHIconLock(size: 15)
                            Text("Earn \(bandGates[band]) stars to open this band")
                                .font(SHTheme.label(11.5, .medium))
                                .foregroundColor(SHTheme.inkFaint)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .cbCard(pad: 14)
            }
        }
    }

    private func bandStars(_ band: Int) -> Int {
        SHTrialData.band(band).reduce(0) { $0 + store.stars(forTrial: $1.id) }
    }

    private func trialRow(_ t: SHTrial) -> some View {
        Button(action: { session = SHSession(mode: .trials, trialID: t.id) }) {
            HStack(spacing: 10) {
                Text("\(t.id)")
                    .font(SHTheme.mono(12))
                    .foregroundColor(SHTheme.inkFaint)
                    .frame(width: 22, alignment: .trailing)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.name)
                        .font(SHTheme.label(13.5, .semibold))
                        .foregroundColor(SHTheme.ink)
                    Text(t.goalText + (t.wind > 0 ? "  ·  wind" : ""))
                        .font(SHTheme.label(10.5, .regular))
                        .foregroundColor(SHTheme.inkSoft)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 3) {
                    SHStarRow(earned: store.stars(forTrial: t.id), size: 11)
                    if store.best(forTrial: t.id) > 0 {
                        Text(t.metricText(store.best(forTrial: t.id)))
                            .font(SHTheme.mono(9.5))
                            .foregroundColor(SHTheme.inkFaint)
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

struct SHDailyView: View {
    @ObservedObject var store = SHStore.shared
    @Binding var session: SHSession?

    private var todayKey: String { SHDaily.todayKey() }

    var body: some View {
        SHScreen(spacing: 12) {
            SHBackRow()
            SHScreenTitle(title: "Daily Cairn",
                          subtitle: SHFormat.prettyDayFormatter.string(from: Date()))

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    dailyStat("Streak", "\(store.data.dailyStreak)")
                    Rectangle().fill(SHTheme.hairline).frame(width: 1, height: 30)
                    dailyStat("Days built", "\(store.data.dailyDone.count)")
                    Rectangle().fill(SHTheme.hairline).frame(width: 1, height: 30)
                    dailyStat("Today's best", store.dailyBest(todayKey).map { SHFormat.height($0) + " pt" } ?? "—")
                }
                Text(store.dailyIsDone(todayKey)
                     ? "Today's cairn is built. The same twelve stones stay available if you want a taller one."
                     : "Twelve stones, seeded from today's date. Seat every one of them to complete the day.")
                    .font(SHTheme.label(11.5, .regular))
                    .foregroundColor(SHTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                SHWideButton(title: store.dailyIsDone(todayKey) ? "Build It Again" : "Build Today's Cairn",
                             tone: SHTheme.seaglass) {
                    session = SHSession(mode: .daily, dayKey: todayKey)
                }
            }
            .cbCard(pad: 14)

            SHSectionHeader(text: "Today's stones")
            VStack(alignment: .leading, spacing: 8) {
                let ids = SHDaily.stones(for: todayKey)
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(0..<4, id: \.self) { col in
                            let i = row * 4 + col
                            if i < ids.count {
                                VStack(spacing: 2) {
                                    SHStonePortrait(kindID: ids[i], boxSize: CGSize(width: 58, height: 40))
                                    Text(SHCatalog.kind(ids[i]).name)
                                        .font(SHTheme.label(8, .medium))
                                        .foregroundColor(SHTheme.inkFaint)
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

            SHSectionHeader(text: "Last 30 days")
            VStack(alignment: .leading, spacing: 8) {
                SHDailyRibbon()
                    .frame(height: 62)
                HStack(spacing: 12) {
                    ribbonKey(color: SHTheme.moss, text: "built")
                    ribbonKey(color: SHTheme.driftwood.opacity(0.55), text: "attempted")
                    ribbonKey(color: SHTheme.paperDeep, text: "missed")
                }
            }
            .cbCard(pad: 12)
        }
    }

    private func dailyStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(SHTheme.monoBold(15))
                .foregroundColor(SHTheme.ink)
            Text(label)
                .font(SHTheme.label(9.5, .medium))
                .foregroundColor(SHTheme.inkFaint)
        }
        .frame(maxWidth: .infinity)
    }

    private func ribbonKey(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(text)
                .font(SHTheme.label(10, .regular))
                .foregroundColor(SHTheme.inkFaint)
        }
    }
}

/// Thirty-day history ribbon drawn on Canvas.
struct SHDailyRibbon: View {
    @ObservedObject var store = SHStore.shared

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            Canvas { ctx, _ in
                let days = SHDaily.lastDays(30)
                let gap: CGFloat = 2.5
                let cw = max(3, (size.width - gap * 29) / 30)
                let maxBest = max(60.0, store.data.dailyBestValues.max() ?? 60)
                for (i, key) in days.enumerated() {
                    let x = CGFloat(i) * (cw + gap)
                    let done = store.dailyIsDone(key)
                    let best = store.dailyBest(key)
                    let baseRect = CGRect(x: x, y: size.height - 12, width: cw, height: 10)
                    let color: Color = done ? SHTheme.moss
                        : (best != nil ? SHTheme.driftwood.opacity(0.55) : SHTheme.paperDeep)
                    ctx.fill(Path(roundedRect: baseRect, cornerRadius: 2), with: .color(color))
                    if let b = best, b > 0 {
                        let h = CGFloat(cbClamp(b / maxBest, 0.06, 1)) * (size.height - 18)
                        let r = CGRect(x: x, y: size.height - 14 - h, width: cw, height: h)
                        ctx.fill(Path(roundedRect: r, cornerRadius: 1.5),
                                 with: .color(color.opacity(0.55)))
                    }
                }
                let label = Text("30 days")
                    .font(SHTheme.label(9, .medium))
                    .foregroundColor(SHTheme.inkFaint)
                ctx.draw(label, at: CGPoint(x: size.width - 22, y: 6))
            }
            .frame(width: size.width, height: size.height)
        }
    }
}
