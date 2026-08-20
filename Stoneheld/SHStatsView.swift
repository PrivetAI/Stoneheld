import SwiftUI

struct SHStatsView: View {
    @ObservedObject var store = SHStore.shared

    private var shoreNames: [String] { SHShores.all.map { $0.name } }

    var body: some View {
        SHScreen(spacing: 12) {
            SHBackRow()
            SHScreenTitle(title: "Progress",
                          subtitle: "Everything below is measured from your own runs.")

            summaryGrid

            SHSectionHeader(text: "Stones seated by shore")
            VStack(alignment: .leading, spacing: 8) {
                SHShoreBarChart(values: store.data.shorePlaced, labels: shoreNames)
                    .frame(height: 148)
                Text("Total seated \(store.data.totalStonesPlaced) across \(store.data.totalRuns) run\(store.data.totalRuns == 1 ? "" : "s").")
                    .font(SHTheme.label(11, .regular))
                    .foregroundColor(SHTheme.inkSoft)
            }
            .cbCard(pad: 14)

            SHSectionHeader(text: "Trial stars by band")
            VStack(alignment: .leading, spacing: 10) {
                ForEach(0..<4, id: \.self) { b in
                    let earned = SHTrialData.band(b).reduce(0) { $0 + store.stars(forTrial: $1.id) }
                    SHProgressBarRow(title: SHBands.names[b],
                                     value: Double(earned), total: 30,
                                     valueText: "\(earned)/30",
                                     color: SHTheme.driftwood)
                }
                Rectangle().fill(SHTheme.hairline).frame(height: 1)
                SHProgressBarRow(title: "All trials",
                                 value: Double(store.totalStars), total: Double(SHTrialData.maxStars),
                                 valueText: "\(store.totalStars)/\(SHTrialData.maxStars)",
                                 color: SHTheme.slate)
            }
            .cbCard(pad: 14)

            SHSectionHeader(text: "Collection")
            VStack(alignment: .leading, spacing: 10) {
                ForEach(SHShores.all, id: \.index) { s in
                    SHProgressBarRow(title: s.name,
                                     value: Double(store.shoreUnlocked(s.index)), total: 9,
                                     valueText: "\(store.shoreUnlocked(s.index))/9",
                                     color: SHTheme.moss)
                }
            }
            .cbCard(pad: 14)

            SHSectionHeader(text: "Gallery heights")
            VStack(alignment: .leading, spacing: 8) {
                if store.data.gallery.isEmpty {
                    Text("No saved cairns yet. Finish a run and the height of each one is plotted here.")
                        .font(SHTheme.label(11.5, .regular))
                        .foregroundColor(SHTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 12)
                } else {
                    SHHeightRibbon(values: store.data.gallery.suffix(24).map { $0.height })
                        .frame(height: 120)
                    Text("Last \(min(24, store.data.gallery.count)) saved cairns, oldest on the left.")
                        .font(SHTheme.label(10.5, .regular))
                        .foregroundColor(SHTheme.inkFaint)
                }
            }
            .cbCard(pad: 14)

            SHSectionHeader(text: "Daily")
            VStack(alignment: .leading, spacing: 8) {
                SHDailyRibbon().frame(height: 62)
                HStack {
                    Text("Streak \(store.data.dailyStreak)")
                    Spacer()
                    Text("Built \(store.data.dailyDone.count) day\(store.data.dailyDone.count == 1 ? "" : "s")")
                }
                .font(SHTheme.mono(11))
                .foregroundColor(SHTheme.inkFaint)
            }
            .cbCard(pad: 14)
        }
    }

    private var summaryGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                tile("Stones seated", "\(store.data.totalStonesPlaced)")
                tile("Tallest cairn", SHFormat.height(store.data.tallestCairn) + " pt")
            }
            HStack(spacing: 10) {
                tile("Longest Zen run", "\(store.data.bestZenStones) stones")
                tile("Windward best", SHFormat.height(store.data.bestWindwardHeight) + " pt")
            }
            HStack(spacing: 10) {
                tile("Trial stars", "\(store.totalStars)/\(SHTrialData.maxStars)")
                tile("Stones unlocked", "\(store.unlockedCount)/\(SHCatalog.count)")
            }
        }
    }

    private func tile(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(SHTheme.monoBold(16))
                .foregroundColor(SHTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(SHTheme.label(10, .medium))
                .foregroundColor(SHTheme.inkFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SHTheme.card))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(SHTheme.cardEdge, lineWidth: 1))
    }
}

// MARK: - Charts (all drawn, nothing placeholder)

struct SHShoreBarChart: View {
    let values: [Int]
    let labels: [String]

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            Canvas { ctx, _ in
                let n = max(1, min(values.count, labels.count))
                let maxV = Double(max(1, values.prefix(n).max() ?? 1))
                let chartH = size.height - 30
                let gap: CGFloat = 12
                let bw = max(8, (size.width - gap * CGFloat(n - 1)) / CGFloat(n))

                // baseline
                var base = Path()
                base.move(to: CGPoint(x: 0, y: chartH))
                base.addLine(to: CGPoint(x: size.width, y: chartH))
                ctx.stroke(base, with: .color(SHTheme.hairline), lineWidth: 1)

                // gridlines
                for g in 1...3 {
                    let y = chartH - chartH * CGFloat(g) / 4
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(line, with: .color(SHTheme.hairline), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                }

                for i in 0..<n {
                    let v = Double(values[i])
                    let h = CGFloat(cbSafeDivide(v, maxV)) * (chartH - 12)
                    let x = CGFloat(i) * (bw + gap)
                    let rect = CGRect(x: x, y: chartH - max(2, h), width: bw, height: max(2, h))
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 4),
                             with: .color(SHTheme.stoneTints[min(i * 2, SHTheme.stoneTints.count - 1)]))
                    let vt = Text("\(values[i])")
                        .font(SHTheme.monoBold(11))
                        .foregroundColor(SHTheme.ink)
                    ctx.draw(vt, at: CGPoint(x: rect.midX, y: rect.minY - 9))
                    let lt = Text(shortLabel(labels[i]))
                        .font(SHTheme.label(9.5, .medium))
                        .foregroundColor(SHTheme.inkFaint)
                    ctx.draw(lt, at: CGPoint(x: rect.midX, y: chartH + 12))
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }

    private func shortLabel(_ s: String) -> String {
        s.split(separator: " ").first.map(String.init) ?? s
    }
}

struct SHProgressBarRow: View {
    let title: String
    let value: Double
    let total: Double
    let valueText: String
    var color: Color = SHTheme.slate

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(SHTheme.label(12, .medium))
                    .foregroundColor(SHTheme.ink)
                Spacer()
                Text(valueText)
                    .font(SHTheme.mono(11))
                    .foregroundColor(SHTheme.inkFaint)
            }
            GeometryReader { geo in
                let frac = CGFloat(cbClamp(cbSafeDivide(value, total), 0, 1))
                ZStack(alignment: .leading) {
                    Capsule().fill(SHTheme.paperDeep)
                    Capsule().fill(color).frame(width: max(frac > 0 ? 4 : 0, geo.size.width * frac))
                }
            }
            .frame(height: 8)
        }
    }
}

struct SHHeightRibbon: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            Canvas { ctx, _ in
                guard !values.isEmpty else { return }
                let maxV = max(40.0, values.max() ?? 40)
                let n = values.count
                let stepX = n > 1 ? size.width / CGFloat(n - 1) : size.width
                let bottom = size.height - 16

                for g in 0...3 {
                    let y = bottom - bottom * CGFloat(g) / 3
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(line, with: .color(SHTheme.hairline), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                }

                func point(_ i: Int) -> CGPoint {
                    let x = n > 1 ? CGFloat(i) * stepX : size.width / 2
                    let y = bottom - CGFloat(cbClamp(cbSafeDivide(values[i], maxV), 0, 1)) * (bottom - 8)
                    return CGPoint(x: x, y: y)
                }

                var area = Path()
                area.move(to: CGPoint(x: point(0).x, y: bottom))
                for i in 0..<n { area.addLine(to: point(i)) }
                area.addLine(to: CGPoint(x: point(n - 1).x, y: bottom))
                area.closeSubpath()
                ctx.fill(area, with: .linearGradient(
                    Gradient(colors: [SHTheme.seaglass.opacity(0.42), SHTheme.seaglass.opacity(0.05)]),
                    startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: bottom)))

                var line = Path()
                for i in 0..<n {
                    if i == 0 { line.move(to: point(i)) } else { line.addLine(to: point(i)) }
                }
                ctx.stroke(line, with: .color(SHTheme.seaglass),
                           style: StrokeStyle(lineWidth: 2, lineJoin: .round))

                for i in 0..<n {
                    let p = point(i)
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2.4, y: p.y - 2.4, width: 4.8, height: 4.8)),
                             with: .color(SHTheme.slate))
                }

                let top = Text("\(Int(maxV)) pt")
                    .font(SHTheme.mono(9.5))
                    .foregroundColor(SHTheme.inkFaint)
                ctx.draw(top, at: CGPoint(x: 22, y: 8))
                let last = Text("latest \(Int(values[n - 1])) pt")
                    .font(SHTheme.mono(9.5))
                    .foregroundColor(SHTheme.inkFaint)
                ctx.draw(last, at: CGPoint(x: size.width - 42, y: size.height - 5))
            }
            .frame(width: size.width, height: size.height)
        }
    }
}
