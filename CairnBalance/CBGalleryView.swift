import SwiftUI

struct CBGalleryView: View {
    @ObservedObject var store = CBStore.shared
    @State private var selected: CBCairnSnapshot?
    @State private var sortNewestFirst = true

    private var items: [CBCairnSnapshot] {
        let g = store.data.gallery
        return sortNewestFirst ? g.reversed() : g
    }

    var body: some View {
        CBScreen(spacing: 12) {
            CBScreenTitle(title: "Gallery",
                          subtitle: "\(store.data.gallery.count) of \(CBStore.galleryLimit) cairns kept")

            if store.data.gallery.isEmpty {
                emptyState
            } else {
                HStack(spacing: 8) {
                    Button(action: { sortNewestFirst.toggle() }) {
                        HStack(spacing: 6) {
                            Text(sortNewestFirst ? "Newest first" : "Oldest first")
                                .font(CBTheme.label(12, .semibold))
                                .foregroundColor(CBTheme.slate)
                            CBIconChevron(size: 11, color: CBTheme.inkFaint)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Capsule().fill(CBTheme.card))
                        .overlay(Capsule().stroke(CBTheme.cardEdge, lineWidth: 1))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                    Text("Tallest \(CBFormat.height(store.data.gallery.map { $0.height }.max() ?? 0)) pt")
                        .font(CBTheme.mono(11))
                        .foregroundColor(CBTheme.inkFaint)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(items) { snap in
                        Button(action: { selected = snap }) {
                            cell(snap)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(item: $selected) { snap in
            CBCairnDetailView(snapshot: snap)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Canvas { ctx, size in
                var c = ctx
                CBRender.drawCairn(&c, kindIDs: [10, 4, 25],
                                   xs: [0, 3, -2], ys: [14, 34, 60], rots: [0, 0.08, -0.05],
                                   in: CGRect(x: 20, y: 10, width: size.width - 40, height: size.height - 20),
                                   withBase: true)
            }
            .frame(height: 120)
            .opacity(0.4)
            Text("No cairns yet")
                .font(CBTheme.displayBold(17))
                .foregroundColor(CBTheme.ink)
            Text("Finish a Zen or Windward run with at least three stones, pass a trial, or complete a Daily Cairn and it is kept here as a vector record.")
                .font(CBTheme.label(11.5, .regular))
                .foregroundColor(CBTheme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .cbCard(pad: 18)
    }

    private func cell(_ snap: CBCairnSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Canvas { ctx, size in
                var c = ctx
                CBRender.drawCairn(&c, kindIDs: snap.kindIDs, xs: snap.xs, ys: snap.ys, rots: snap.rots,
                                   in: CGRect(x: 6, y: 6, width: size.width - 12, height: size.height - 12),
                                   withBase: true)
            }
            .frame(height: 116)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(CBTheme.fog.opacity(0.5))
            )
            Text(snap.name)
                .font(CBTheme.label(12, .semibold))
                .foregroundColor(CBTheme.ink)
                .lineLimit(1)
            HStack(spacing: 5) {
                Text("\(snap.stoneCount) st")
                Text("·")
                Text("\(CBFormat.height(snap.height)) pt")
            }
            .font(CBTheme.mono(9.5))
            .foregroundColor(CBTheme.inkFaint)
        }
        .cbCard(pad: 9, radius: 12)
    }
}

// MARK: - Detail

struct CBCairnDetailView: View {
    let snapshot: CBCairnSnapshot
    @ObservedObject var store = CBStore.shared
    @Environment(\.presentationMode) private var presentation

    @State private var name: String = ""
    @State private var confirmDelete = false
    @FocusState private var nameFocused: Bool

    private var live: CBCairnSnapshot {
        store.data.gallery.first(where: { $0.id == snapshot.id }) ?? snapshot
    }

    var body: some View {
        ZStack(alignment: .top) {
            CBBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(live.name)
                            .font(CBTheme.displayBold(20))
                            .foregroundColor(CBTheme.ink)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        Button(action: { presentation.wrappedValue.dismiss() }) {
                            CBIconClose(size: 18)
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Canvas { ctx, size in
                        var c = ctx
                        CBRender.drawCairn(&c, kindIDs: live.kindIDs, xs: live.xs, ys: live.ys,
                                           rots: live.rots,
                                           in: CGRect(x: 14, y: 10, width: size.width - 28, height: size.height - 20),
                                           withBase: true)
                    }
                    .frame(height: 280)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(CBTheme.fog.opacity(0.5))
                    )

                    HStack(spacing: 0) {
                        stat("Stones", "\(live.stoneCount)")
                        rule
                        stat("Height", CBFormat.height(live.height) + " pt")
                        rule
                        stat("Min margin", CBFormat.margin(live.minMargin))
                    }
                    .cbCard(pad: 12)

                    VStack(alignment: .leading, spacing: 6) {
                        CBSectionHeader(text: "Record")
                        detailRow("Mode", live.modeEnum.title)
                        detailRow("Source", live.label)
                        detailRow("Saved", CBFormat.prettyDayFormatter.string(from: live.date))
                    }
                    .cbCard(pad: 14)

                    VStack(alignment: .leading, spacing: 8) {
                        CBSectionHeader(text: "Name")
                        HStack(spacing: 8) {
                            TextField("Cairn name", text: $name)
                                .font(CBTheme.label(14, .regular))
                                .foregroundColor(CBTheme.ink)
                                .focused($nameFocused)
                                .padding(.horizontal, 10).padding(.vertical, 9)
                                .background(RoundedRectangle(cornerRadius: 9).fill(CBTheme.paper))
                                .overlay(RoundedRectangle(cornerRadius: 9).stroke(CBTheme.cardEdge, lineWidth: 1))
                                .contentShape(Rectangle())
                                .onTapGesture { nameFocused = true }
                            Button(action: {
                                nameFocused = false
                                store.renameSnapshot(id: live.id, to: name)
                            }) {
                                Text("Save")
                                    .font(CBTheme.label(13, .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 9).fill(CBTheme.slate))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .cbCard(pad: 14)

                    Button(action: { confirmDelete = true }) {
                        HStack(spacing: 8) {
                            CBIconTrash(size: 15)
                            Text("Delete this cairn")
                                .font(CBTheme.label(13.5, .semibold))
                                .foregroundColor(CBTheme.rust)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 12).padding(.horizontal, 14)
                        .background(RoundedRectangle(cornerRadius: 12).stroke(CBTheme.rust.opacity(0.45), lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, CBSafe.top + 12)
                .padding(.bottom, 40)
            }
            CBStatusStrip()
        }
        .onAppear { name = live.name }
        .alert("Delete this cairn?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                store.deleteSnapshot(id: live.id)
                presentation.wrappedValue.dismiss()
            }
        } message: {
            Text("The record is removed permanently. This cannot be undone.")
        }
    }

    private var rule: some View {
        Rectangle().fill(CBTheme.hairline).frame(width: 1, height: 28)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(CBTheme.monoBold(14))
                .foregroundColor(CBTheme.ink)
            Text(label)
                .font(CBTheme.label(9.5, .medium))
                .foregroundColor(CBTheme.inkFaint)
        }
        .frame(maxWidth: .infinity)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(CBTheme.label(12, .regular))
                .foregroundColor(CBTheme.inkSoft)
            Spacer(minLength: 8)
            Text(value)
                .font(CBTheme.label(12, .semibold))
                .foregroundColor(CBTheme.ink)
        }
    }
}
