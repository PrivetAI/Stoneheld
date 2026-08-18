import SwiftUI

private struct CBStoneRef: Identifiable {
    let id: Int
}

struct CBStonesView: View {
    @ObservedObject var store = CBStore.shared
    @State private var selected: CBStoneRef?
    @State private var shoreFilter: Int = -1

    var body: some View {
        CBScreen(spacing: 12) {
            CBScreenTitle(title: "Stones",
                          subtitle: "\(store.unlockedCount) of \(CBCatalog.count) unlocked across four shores")

            filterRow

            ForEach(CBShores.all, id: \.index) { shore in
                if shoreFilter == -1 || shoreFilter == shore.index {
                    shoreSection(shore)
                }
            }
        }
        .sheet(item: $selected) { ref in
            CBStoneDetailView(kindID: ref.id)
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All shores", active: shoreFilter == -1) { shoreFilter = -1 }
                ForEach(CBShores.all, id: \.index) { s in
                    chip(title: s.name, active: shoreFilter == s.index) { shoreFilter = s.index }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(CBTheme.label(12, .semibold))
                .foregroundColor(active ? .white : CBTheme.slate)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(active ? CBTheme.slate : CBTheme.card))
                .overlay(Capsule().stroke(CBTheme.cardEdge, lineWidth: active ? 0 : 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func shoreSection(_ shore: CBShore) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(shore.name)
                        .font(CBTheme.displayBold(17))
                        .foregroundColor(CBTheme.ink)
                    Text(shore.blurb)
                        .font(CBTheme.label(11, .regular))
                        .foregroundColor(CBTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text("\(store.shoreUnlocked(shore.index))/9")
                    .font(CBTheme.mono(12))
                    .foregroundColor(CBTheme.inkFaint)
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
        let kind = CBCatalog.kind(id)
        let unlocked = store.isUnlocked(id)
        return Button(action: { selected = CBStoneRef(id: id) }) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(CBTheme.fog.opacity(0.45))
                    CBStonePortrait(kindID: id, boxSize: CGSize(width: 116, height: 62), locked: !unlocked)
                    if !unlocked {
                        CBIconLock(size: 18, color: CBTheme.inkSoft)
                    }
                }
                .frame(height: 66)
                Text(unlocked ? kind.name : "Locked")
                    .font(CBTheme.label(11.5, .semibold))
                    .foregroundColor(unlocked ? CBTheme.ink : CBTheme.inkFaint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(unlocked ? "\(Int(kind.width)) x \(Int(kind.height)) pt" : "—")
                    .font(CBTheme.mono(9))
                    .foregroundColor(CBTheme.inkFaint)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stone detail

struct CBStoneDetailView: View {
    let kindID: Int
    @ObservedObject var store = CBStore.shared
    @Environment(\.presentationMode) private var presentation

    private var kind: CBStoneKind { CBCatalog.kind(kindID) }
    private var unlocked: Bool { store.isUnlocked(kindID) }

    var body: some View {
        ZStack(alignment: .top) {
            CBBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(unlocked ? kind.name : "Locked stone")
                                .font(CBTheme.displayBold(21))
                                .foregroundColor(CBTheme.ink)
                            Text(CBShores.shore(of: kindID).name)
                                .font(CBTheme.label(12, .medium))
                                .foregroundColor(CBTheme.inkSoft)
                        }
                        Spacer(minLength: 8)
                        Button(action: { presentation.wrappedValue.dismiss() }) {
                            CBIconClose(size: 18).padding(8).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(CBTheme.fog.opacity(0.5))
                        GeometryReader { geo in
                            CBStonePortrait(kindID: kindID,
                                            boxSize: CGSize(width: geo.size.width, height: geo.size.height),
                                            locked: !unlocked)
                        }
                        .padding(14)
                        if !unlocked { CBIconLock(size: 34, color: CBTheme.inkSoft) }
                    }
                    .frame(height: 220)

                    if unlocked {
                        Text(kind.note)
                            .font(CBTheme.label(13, .regular))
                            .foregroundColor(CBTheme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 8) {
                            CBSectionHeader(text: "Geometry")
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
                        CBSectionHeader(text: "Where it comes from")
                        Text(CBShores.shore(of: kindID).blurb)
                            .font(CBTheme.label(12, .regular))
                            .foregroundColor(CBTheme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        Rectangle().fill(CBTheme.hairline).frame(height: 1)
                        HStack(spacing: 8) {
                            if unlocked { CBIconCheck(size: 15) } else { CBIconLock(size: 15) }
                            Text(store.unlockText(kindID))
                                .font(CBTheme.label(12, .medium))
                                .foregroundColor(unlocked ? CBTheme.moss : CBTheme.inkSoft)
                        }
                    }
                    .cbCard(pad: 14)
                }
                .padding(.horizontal, 16)
                .padding(.top, CBSafe.top + 12)
                .padding(.bottom, 40)
            }
            CBStatusStrip()
        }
    }

    private func textureName(_ t: CBTexture) -> String {
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
                .font(CBTheme.label(12, .regular))
                .foregroundColor(CBTheme.inkSoft)
            Spacer(minLength: 8)
            Text(value)
                .font(CBTheme.mono(12))
                .foregroundColor(CBTheme.ink)
        }
    }
}
