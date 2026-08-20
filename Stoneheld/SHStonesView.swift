import SwiftUI

private struct SHStoneRef: Identifiable {
    let id: Int
}

struct SHStonesView: View {
    @ObservedObject var store = SHStore.shared
    @State private var selected: SHStoneRef?
    @State private var shoreFilter: Int = -1

    var body: some View {
        SHScreen(spacing: 12) {
            SHScreenTitle(title: "Stones",
                          subtitle: "\(store.unlockedCount) of \(SHCatalog.count) unlocked across four shores")

            filterRow

            ForEach(SHShores.all, id: \.index) { shore in
                if shoreFilter == -1 || shoreFilter == shore.index {
                    shoreSection(shore)
                }
            }
        }
        .sheet(item: $selected) { ref in
            SHStoneDetailView(kindID: ref.id)
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All shores", active: shoreFilter == -1) { shoreFilter = -1 }
                ForEach(SHShores.all, id: \.index) { s in
                    chip(title: s.name, active: shoreFilter == s.index) { shoreFilter = s.index }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(SHTheme.label(12, .semibold))
                .foregroundColor(active ? .white : SHTheme.slate)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(active ? SHTheme.slate : SHTheme.card))
                .overlay(Capsule().stroke(SHTheme.cardEdge, lineWidth: active ? 0 : 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func shoreSection(_ shore: SHShore) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(shore.name)
                        .font(SHTheme.displayBold(17))
                        .foregroundColor(SHTheme.ink)
                    Text(shore.blurb)
                        .font(SHTheme.label(11, .regular))
                        .foregroundColor(SHTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text("\(store.shoreUnlocked(shore.index))/9")
                    .font(SHTheme.mono(12))
                    .foregroundColor(SHTheme.inkFaint)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(shore.range), id: \.self) { id in
                    stoneCell(id)
                }
            }
        }
        .cbCard(pad: 14)
    }

    private func stoneCell(_ id: Int) -> some View {
        let kind = SHCatalog.kind(id)
        let unlocked = store.isUnlocked(id)
        return Button(action: { selected = SHStoneRef(id: id) }) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(SHTheme.fog.opacity(0.45))
                    SHStonePortrait(kindID: id, boxSize: CGSize(width: 116, height: 62), locked: !unlocked)
                    if !unlocked {
                        SHIconLock(size: 18, color: SHTheme.inkSoft)
                    }
                }
                .frame(height: 66)
                Text(unlocked ? kind.name : "Locked")
                    .font(SHTheme.label(11.5, .semibold))
                    .foregroundColor(unlocked ? SHTheme.ink : SHTheme.inkFaint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(unlocked ? "\(Int(kind.width)) x \(Int(kind.height)) pt" : "—")
                    .font(SHTheme.mono(9))
                    .foregroundColor(SHTheme.inkFaint)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stone detail

struct SHStoneDetailView: View {
    let kindID: Int
    @ObservedObject var store = SHStore.shared
    @Environment(\.presentationMode) private var presentation

    private var kind: SHStoneKind { SHCatalog.kind(kindID) }
    private var unlocked: Bool { store.isUnlocked(kindID) }

    var body: some View {
        ZStack(alignment: .top) {
            SHBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(unlocked ? kind.name : "Locked stone")
                                .font(SHTheme.displayBold(21))
                                .foregroundColor(SHTheme.ink)
                            Text(SHShores.shore(of: kindID).name)
                                .font(SHTheme.label(12, .medium))
                                .foregroundColor(SHTheme.inkSoft)
                        }
                        Spacer(minLength: 8)
                        Button(action: { presentation.wrappedValue.dismiss() }) {
                            SHIconClose(size: 18).padding(8).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(SHTheme.fog.opacity(0.5))
                        GeometryReader { geo in
                            SHStonePortrait(kindID: kindID,
                                            boxSize: CGSize(width: geo.size.width, height: geo.size.height),
                                            locked: !unlocked)
                        }
                        .padding(14)
                        if !unlocked { SHIconLock(size: 34, color: SHTheme.inkSoft) }
                    }
                    .frame(height: 220)

                    if unlocked {
                        Text(kind.note)
                            .font(SHTheme.label(13, .regular))
                            .foregroundColor(SHTheme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 8) {
                            SHSectionHeader(text: "Geometry")
                            row("Vertices", "\(kind.poly.points.count)")
                            row("Footprint", "\(Int(kind.width)) x \(Int(kind.height)) pt")
                            row("Area", String(format: "%.0f pt²", kind.poly.area))
                            row("Density", String(format: "%.2f", kind.density))
                            row("Mass", String(format: "%.0f", kind.mass))
                            row("Centroid offset", String(format: "%.1f, %.1f",
                                                         Double(kind.poly.centroid.x),
                                                         Double(kind.poly.centroid.y)))
                            row("Surface", textureName(kind.texture))
                        }
                        .cbCard(pad: 14)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SHSectionHeader(text: "Where it comes from")
                        Text(SHShores.shore(of: kindID).blurb)
                            .font(SHTheme.label(12, .regular))
                            .foregroundColor(SHTheme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        Rectangle().fill(SHTheme.hairline).frame(height: 1)
                        HStack(spacing: 8) {
                            if unlocked { SHIconCheck(size: 15) } else { SHIconLock(size: 15) }
                            Text(store.unlockText(kindID))
                                .font(SHTheme.label(12, .medium))
                                .foregroundColor(unlocked ? SHTheme.moss : SHTheme.inkSoft)
                        }
                    }
                    .cbCard(pad: 14)
                }
                .padding(.horizontal, 16)
                .padding(.top, SHSafe.top + 12)
                .padding(.bottom, 40)
            }
            SHStatusStrip()
        }
    }

    private func textureName(_ t: SHTexture) -> String {
        switch t {
        case .speckle: return "Speckled"
        case .banding: return "Banded"
        case .veins: return "Veined"
        case .grain: return "Grained"
        case .rings: return "Ringed"
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(SHTheme.label(12, .regular))
                .foregroundColor(SHTheme.inkSoft)
            Spacer(minLength: 8)
            Text(value)
                .font(SHTheme.mono(12))
                .foregroundColor(SHTheme.ink)
        }
    }
}
