import SwiftUI

struct CBSettingsView: View {
    @ObservedObject var store = CBStore.shared
    @State private var showPrivacy = false
    @State private var confirmReset = false

    private var versionText: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        CBScreen(spacing: 12) {
            CBScreenTitle(title: "Settings",
                          subtitle: "Overlays, controls and your saved progress.")

            NavigationLink(destination: CBStatsView()) {
                HStack(spacing: 10) {
                    CBIconCairn(size: 22, color: CBTheme.slate)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Progress and Stats")
                            .font(CBTheme.label(14, .semibold))
                            .foregroundColor(CBTheme.ink)
                        Text("\(store.data.totalStonesPlaced) stones seated  ·  \(store.totalStars) stars")
                            .font(CBTheme.label(11, .regular))
                            .foregroundColor(CBTheme.inkSoft)
                    }
                    Spacer(minLength: 0)
                    CBIconChevron(size: 14, color: CBTheme.inkFaint)
                }
                .cbCard(pad: 14)
            }
            .buttonStyle(.plain)

            CBSectionHeader(text: "Placement overlays")
            VStack(spacing: 0) {
                toggleRow("Centre of mass plumb line",
                          "The dashed line showing where the combined mass lands.",
                          store.data.showPlumb) { store.mutate { $0.showPlumb.toggle() } }
                divider
                toggleRow("Support interval",
                          "Highlights the contact the stones above actually rest on.",
                          store.data.showSupport) { store.mutate { $0.showSupport.toggle() } }
                divider
                toggleRow("Balance meter",
                          "The green to rust bar reading the weakest margin.",
                          store.data.showMeter) { store.mutate { $0.showMeter.toggle() } }
            }
            .cbCard(pad: 14)

            CBSectionHeader(text: "Controls")
            VStack(spacing: 12) {
                segmentRow(title: "Rotation step",
                           options: ["1°", "5°"],
                           index: store.data.rotationStep == 5 ? 1 : 0) { i in
                    store.mutate { $0.rotationStep = i == 1 ? 5 : 1 }
                }
                divider
                segmentRow(title: "Twist ring side",
                           options: ["Left", "Right"],
                           index: store.data.controlOnRight ? 1 : 0) { i in
                    store.mutate { $0.controlOnRight = i == 1 }
                }
                divider
                toggleRow("Haptics", "Light feedback on release and on a seated stone.",
                          store.data.haptics) { store.mutate { $0.haptics.toggle() } }
                divider
                toggleRow("Gentle wind in Zen", "Adds a small lateral force to endless runs.",
                          store.data.zenWind) { store.mutate { $0.zenWind.toggle() } }
            }
            .cbCard(pad: 14)

            CBSectionHeader(text: "About")
            VStack(spacing: 0) {
                Button(action: { store.mutate { $0.onboardingDone = false } }) {
                    HStack {
                        Text("Replay the explainer")
                            .font(CBTheme.label(13.5, .medium))
                            .foregroundColor(CBTheme.ink)
                        Spacer()
                        CBIconChevron(size: 13, color: CBTheme.inkFaint)
                    }
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                divider
                Button(action: { showPrivacy = true }) {
                    HStack {
                        Text("Privacy Policy")
                            .font(CBTheme.label(13.5, .medium))
                            .foregroundColor(CBTheme.ink)
                        Spacer()
                        CBIconChevron(size: 13, color: CBTheme.inkFaint)
                    }
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                divider
                HStack {
                    Text("Version")
                        .font(CBTheme.label(13.5, .medium))
                        .foregroundColor(CBTheme.ink)
                    Spacer()
                    Text(versionText)
                        .font(CBTheme.mono(12))
                        .foregroundColor(CBTheme.inkFaint)
                }
                .padding(.vertical, 11)
            }
            .cbCard(pad: 14)

            Button(action: { confirmReset = true }) {
                HStack(spacing: 8) {
                    CBIconTrash(size: 15)
                    Text("Reset all progress")
                        .font(CBTheme.label(13.5, .semibold))
                        .foregroundColor(CBTheme.rust)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 13).padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(CBTheme.rust.opacity(0.45), lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("Cairn Balance keeps everything on this device. There is no account, no sign-in and no data leaves the phone.")
                .font(CBTheme.label(10.5, .regular))
                .foregroundColor(CBTheme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .sheet(isPresented: $showPrivacy) {
            CairnBalanceWebPanel(urlString: CairnBalanceLinks.privacy)
        }
        .alert("Reset all progress?", isPresented: $confirmReset) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) { store.resetProgress() }
        } message: {
            Text("Stones, stars, daily history and every saved cairn are cleared. Your display and control preferences are kept.")
        }
    }

    private var divider: some View {
        Rectangle().fill(CBTheme.hairline).frame(height: 1)
    }

    private func toggleRow(_ title: String, _ note: String, _ on: Bool,
                           _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(CBTheme.label(13.5, .medium))
                        .foregroundColor(CBTheme.ink)
                        .multilineTextAlignment(.leading)
                    Text(note)
                        .font(CBTheme.label(10.5, .regular))
                        .foregroundColor(CBTheme.inkSoft)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                CBToggleMark(on: on)
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func segmentRow(title: String, options: [String], index: Int,
                            _ action: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(CBTheme.label(13.5, .medium))
                .foregroundColor(CBTheme.ink)
            Spacer(minLength: 8)
            HStack(spacing: 3) {
                ForEach(Array(options.enumerated()), id: \.offset) { item in
                    Button(action: { action(item.offset) }) {
                        Text(item.element)
                            .font(CBTheme.label(12, .semibold))
                            .foregroundColor(item.offset == index ? .white : CBTheme.slate)
                            .frame(width: 52, height: 28)
                            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(item.offset == index ? CBTheme.slate : Color.clear))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(CBTheme.paperDeep))
        }
        .padding(.vertical, 2)
    }
}
