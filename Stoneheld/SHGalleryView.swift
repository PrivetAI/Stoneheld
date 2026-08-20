import SwiftUI

struct SHGalleryView: View {
    @ObservedObject var store = SHStore.shared
    @State private var selected: SHCairnSnapshot?
    @State private var sortNewestFirst = true

    private var items: [SHCairnSnapshot] {
        let g = store.data.gallery
        return sortNewestFirst ? g.reversed() : g
    }

    var body: some View {
        SHScreen(spacing: 12) {
            SHScreenTitle(title: "Gallery",
                          subtitle: "\(store.data.gallery.count) of \(SHStore.galleryLimit) cairns kept")

            if store.data.gallery.isEmpty {
                emptyState
            } else {
                HStack(spacing: 8) {
                    Button(action: { sortNewestFirst.toggle() }) {
                        HStack(spacing: 6) {
                            Text(sortNewestFirst ? "Newest first" : "Oldest first")
                                .font(SHTheme.label(12, .semibold))
                                .foregroundColor(SHTheme.slate)
                            SHIconChevron(size: 11, color: SHTheme.inkFaint)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Capsule().fill(SHTheme.card))
                        .overlay(Capsule().stroke(SHTheme.cardEdge, lineWidth: 1))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                    Text("Tallest \(SHFormat.height(store.data.gallery.map { $0.height }.max() ?? 0)) pt")
                        .font(SHTheme.mono(11))
                        .foregroundColor(SHTheme.inkFaint)
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
            SHCairnDetailView(snapshot: snap)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Canvas { ctx, size in
                var c = ctx
                SHRender.drawCairn(&c, kindIDs: [10, 4, 25],
                                   xs: [0, 3, -2], ys: [14, 34, 60], rots: [0, 0.08, -0.05],
                                   in: CGRect(x: 20, y: 10, width: size.width - 40, height: size.height - 20),
                                   withBase: true)
            }
            .frame(height: 120)
            .opacity(0.4)
            Text("No cairns yet")
                .font(SHTheme.displayBold(17))
                .foregroundColor(SHTheme.ink)
            Text("Finish a Zen or Windward run with at least three stones, pass a trial, or complete a Daily Cairn and it is kept here as a vector record.")
                .font(SHTheme.label(11.5, .regular))
                .foregroundColor(SHTheme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .cbCard(pad: 18)
    }

    private func cell(_ snap: SHCairnSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Canvas { ctx, size in
                var c = ctx
                SHRender.drawCairn(&c, kindIDs: snap.kindIDs, xs: snap.xs, ys: snap.ys, rots: snap.rots,
                                   in: CGRect(x: 6, y: 6, width: size.width - 12, height: size.height - 12),
                                   withBase: true)
            }
            .frame(height: 116)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(SHTheme.fog.opacity(0.5))
            )
            Text(snap.name)
                .font(SHTheme.label(12, .semibold))
                .foregroundColor(SHTheme.ink)
                .lineLimit(1)
            HStack(spacing: 5) {
                Text("\(snap.stoneCount) st")
                Text("·")
                Text("\(SHFormat.height(snap.height)) pt")
            }
            .font(SHTheme.mono(9.5))
            .foregroundColor(SHTheme.inkFaint)
        }
        .cbCard(pad: 9, radius: 12)
    }
}

// MARK: - Detail

struct SHCairnDetailView: View {
    let snapshot: SHCairnSnapshot
    @ObservedObject var store = SHStore.shared
    @Environment(\.presentationMode) private var presentation

    @State private var name: String = ""
    @State private var confirmDelete = false
    @FocusState private var nameFocused: Bool

    private var live: SHCairnSnapshot {
        store.data.gallery.first(where: { $0.id == snapshot.id }) ?? snapshot
    }

    var body: some View {
        ZStack(alignment: .top) {
            SHBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(live.name)
                            .font(SHTheme.displayBold(20))
                            .foregroundColor(SHTheme.ink)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        Button(action: { presentation.wrappedValue.dismiss() }) {
                            SHIconClose(size: 18)
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Canvas { ctx, size in
                        var c = ctx
                        SHRender.drawCairn(&c, kindIDs: live.kindIDs, xs: live.xs, ys: live.ys,
                                           rots: live.rots,
                                           in: CGRect(x: 14, y: 10, width: size.width - 28, height: size.height - 20),
                                           withBase: true)
                    }
                    .frame(height: 280)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(SHTheme.fog.opacity(0.5))
                    )

                    HStack(spacing: 0) {
                        stat("Stones", "\(live.stoneCount)")
                        rule
                        stat("Height", SHFormat.height(live.height) + " pt")
                        rule
                        stat("Min margin", SHFormat.margin(live.minMargin))
                    }
                    .cbCard(pad: 12)

                    VStack(alignment: .leading, spacing: 6) {
                        SHSectionHeader(text: "Record")
                        detailRow("Mode", live.modeEnum.title)
                        detailRow("Source", live.label)
                        detailRow("Saved", SHFormat.prettyDayFormatter.string(from: live.date))
                    }
                    .cbCard(pad: 14)

                    VStack(alignment: .leading, spacing: 8) {
                        SHSectionHeader(text: "Name")
                        HStack(spacing: 8) {
                            TextField("Cairn name", text: $name)
                                .font(SHTheme.label(14, .regular))
                                .foregroundColor(SHTheme.ink)
                                .focused($nameFocused)
                                .padding(.horizontal, 10).padding(.vertical, 9)
                                .background(RoundedRectangle(cornerRadius: 9).fill(SHTheme.paper))
                                .overlay(RoundedRectangle(cornerRadius: 9).stroke(SHTheme.cardEdge, lineWidth: 1))
                                .contentShape(Rectangle())
                                .onTapGesture { nameFocused = true }
                            Button(action: {
                                nameFocused = false
                                store.renameSnapshot(id: live.id, to: name)
                            }) {
                                Text("Save")
                                    .font(SHTheme.label(13, .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 9).fill(SHTheme.slate))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .cbCard(pad: 14)

                    Button(action: { confirmDelete = true }) {
                        HStack(spacing: 8) {
                            SHIconTrash(size: 15)
                            Text("Delete this cairn")
                                .font(SHTheme.label(13.5, .semibold))
                                .foregroundColor(SHTheme.rust)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 12).padding(.horizontal, 14)
                        .background(RoundedRectangle(cornerRadius: 12).stroke(SHTheme.rust.opacity(0.45), lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, SHSafe.top + 12)
                .padding(.bottom, 40)
            }
            SHStatusStrip()
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
        Rectangle().fill(SHTheme.hairline).frame(width: 1, height: 28)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(SHTheme.monoBold(14))
                .foregroundColor(SHTheme.ink)
            Text(label)
                .font(SHTheme.label(9.5, .medium))
                .foregroundColor(SHTheme.inkFaint)
        }
        .frame(maxWidth: .infinity)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(SHTheme.label(12, .regular))
                .foregroundColor(SHTheme.inkSoft)
            Spacer(minLength: 8)
            Text(value)
                .font(SHTheme.label(12, .semibold))
                .foregroundColor(SHTheme.ink)
        }
    }
}
