import SwiftUI

struct CBStatsView: View {
    @ObservedObject var store = CBStore.shared

    private var shoreNames: [String] { CBShores.all.map { $0.name } }

    var body: some View {
        CBScreen(spacing: 12) {
            CBBackRow()
            CBScreenTitle(title: "Progress",
                          subtitle: "Everything below is measured from your own runs.")

            summaryGrid

            CBSectionHeader(text: "Stones seated by shore")
            VStack(alignment: .leading, spacing: 8) {
                CBShoreBarChart(values: store.data.shorePlaced, labels: shoreNames)
                    .frame(height: 148)
                Text("Total seated \(store.data.totalStonesPlaced) across \(store.data.totalRuns) run\(store.data.totalRuns == 1 ? "" : "s").")
                    .font(CBTheme.label(11, .regular))
                    .foregroundColor(CBTheme.inkSoft)
            }
            .cbCard(pad: 14)

            CBSectionHeader(text: "Trial stars by band")
            VStack(alignment: .leading, spacing: 10) {
                ForEach(0..<4, id: \.self) { b in
                    let earned = CBTrialData.band(b).reduce(0) { $0 + store.stars(forTrial: $1.id) }
                    CBProgressBarRow(title: CBBands.names[b],
                                     value: Double(earned), total: 30,
                                     valueText: "\(earned)/30",
                                     color: CBTheme.driftwood)
                }
                Rectangle().fill(CBTheme.hairline).frame(height: 1)
                CBProgressBarRow(title: "All trials",
                                 value: Double(store.totalStars), total: Double(CBTrialData.maxStars),
                                 valueText: "\(store.totalStars)/\(CBTrialData.maxStars)",
                                 color: CBTheme.slate)
            }
            .cbCard(pad: 14)

            CBSectionHeader(text: "Collection")
            VStack(alignment: .leading, spacing: 10) {
                ForEach(CBShores.all, id: \.index) { s in
                    CBProgressBarRow(title: s.name,
                                     value: Double(store.shoreUnlocked(s.index)), total: 9,
                                     valueText: "\(store.shoreUnlocked(s.index))/9",
                                     color: CBTheme.moss)
                }
            }
            .cbCard(pad: 14)

            CBSectionHeader(text: "Gallery heights")
            VStack(alignment: .leading, spacing: 8) {
                if store.data.gallery.isEmpty {
                    Text("No saved cairns yet. Finish a run and the height of each one is plotted here.")
                        .font(CBTheme.label(11.5, .regular))
                        .foregroundColor(CBTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 12)
                } else {
                    CBHeightRibbon(values: store.data.gallery.suffix(24).map { $0.height })
                        .frame(height: 120)
                    Text("Last \(min(24, store.data.gallery.count)) saved cairns, oldest on the left.")
                        .font(CBTheme.label(10.5, .regular))
                        .foregroundColor(CBTheme.inkFaint)
                }
            }
            .cbCard(pad: 14)

            CBSectionHeader(text: "Daily")
            VStack(alignment: .leading, spacing: 8) {
                CBDailyRibbon().frame(height: 62)
                HStack {
                    Text("Streak \(store.data.dailyStreak)")
                    Spacer()
                    Text("Built \(store.data.dailyDone.count) day\(store.data.dailyDone.count == 1 ? "" : "s")")
                }
                .font(CBTheme.mono(11))
                .foregroundColor(CBTheme.inkFaint)
            }
            .cbCard(pad: 14)
        }
    }

    private var summaryGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                tile("Stones seated", "\(store.data.totalStonesPlaced)")
                tile("Tallest cairn", CBFormat.height(store.data.tallestCairn) + " pt")
            }
            HStack(spacing: 10) {
                tile("Longest Zen run", "\(store.data.bestZenStones) stones")
                tile("Windward best", CBFormat.height(store.data.bestWindwardHeight) + " pt")
            }
            HStack(spacing: 10) {
                tile("Trial stars", "\(store.totalStars)/\(CBTrialData.maxStars)")
                tile("Stones unlocked", "\(store.unlockedCount)/\(CBCatalog.count)")
            }
        }
    }

    private func tile(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(CBTheme.monoBold(16))
                .foregroundColor(CBTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(CBTheme.label(10, .medium))
                .foregroundColor(CBTheme.inkFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(CBTheme.card))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(CBTheme.cardEdge, lineWidth: 1))
    }
}

// MARK: - Charts (all drawn, nothing placeholder)

struct CBShoreBarChart: View {
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
                ctx.stroke(base, with: .color(CBTheme.hairline), lineWidth: 1)

                // gridlines
                for g in 1...3 {
                    let y = chartH - chartH * CGFloat(g) / 4
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(line, with: .color(CBTheme.hairline), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                }

                for i in 0..<n {
                    let v = Double(values[i])
                    let h = CGFloat(cbSafeDivide(v, maxV)) * (chartH - 12)
                    let x = CGFloat(i) * (bw + gap)
                    let rect = CGRect(x: x, y: chartH - max(2, h), width: bw, height: max(2, h))
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 4),
                             with: .color(CBTheme.stoneTints[min(i * 2, CBTheme.stoneTints.count - 1)]))
                    let vt = Text("\(values[i])")
                        .font(CBTheme.monoBold(11))
                        .foregroundColor(CBTheme.ink)
                    ctx.draw(vt, at: CGPoint(x: rect.midX, y: rect.minY - 9))
                    let lt = Text(shortLabel(labels[i]))
                        .font(CBTheme.label(9.5, .medium))
                        .foregroundColor(CBTheme.inkFaint)
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

struct CBProgressBarRow: View {
    let title: String
    let value: Double
    let total: Double
    let valueText: String
    var color: Color = CBTheme.slate

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(CBTheme.label(12, .medium))
                    .foregroundColor(CBTheme.ink)
                Spacer()
                Text(valueText)
                    .font(CBTheme.mono(11))
                    .foregroundColor(CBTheme.inkFaint)
            }
            GeometryReader { geo in
                let frac = CGFloat(cbClamp(cbSafeDivide(value, total), 0, 1))
                ZStack(alignment: .leading) {
                    Capsule().fill(CBTheme.paperDeep)
                    Capsule().fill(color).frame(width: max(frac > 0 ? 4 : 0, geo.size.width * frac))
                }
            }
            .frame(height: 8)
        }
    }
}

struct CBHeightRibbon: View {
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
                    ctx.stroke(line, with: .color(CBTheme.hairline), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
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
                    Gradient(colors: [CBTheme.seaglass.opacity(0.42), CBTheme.seaglass.opacity(0.05)]),
                    startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: bottom)))

                var line = Path()
                for i in 0..<n {
                    if i == 0 { line.move(to: point(i)) } else { line.addLine(to: point(i)) }
                }
                ctx.stroke(line, with: .color(CBTheme.seaglass),
                           style: StrokeStyle(lineWidth: 2, lineJoin: .round))

                for i in 0..<n {
                    let p = point(i)
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2.4, y: p.y - 2.4, width: 4.8, height: 4.8)),
                             with: .color(CBTheme.slate))
                }

                let top = Text("\(Int(maxV)) pt")
                    .font(CBTheme.mono(9.5))
                    .foregroundColor(CBTheme.inkFaint)
                ctx.draw(top, at: CGPoint(x: 22, y: 8))
                let last = Text("latest \(Int(values[n - 1])) pt")
                    .font(CBTheme.mono(9.5))
                    .foregroundColor(CBTheme.inkFaint)
                ctx.draw(last, at: CGPoint(x: size.width - 42, y: size.height - 5))
            }
            .frame(width: size.width, height: size.height)
        }
    }
}
