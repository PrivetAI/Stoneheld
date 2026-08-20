import SwiftUI

struct SHRootView: View {
    @ObservedObject var store = SHStore.shared
    @State private var tab = 0
    @State private var session: SHSession?

    var body: some View {
        ZStack {
            ZStack(alignment: .bottom) {
                Group {
                    switch tab {
                    case 0:
                        NavigationView { SHStackView(session: $session) }
                            .navigationViewStyle(StackNavigationViewStyle())
                    case 1:
                        NavigationView { SHGalleryView() }
                            .navigationViewStyle(StackNavigationViewStyle())
                    case 2:
                        NavigationView { SHStonesView() }
                            .navigationViewStyle(StackNavigationViewStyle())
                    default:
                        NavigationView { SHSettingsView() }
                            .navigationViewStyle(StackNavigationViewStyle())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                tabBar
            }
            .edgesIgnoringSafeArea(.bottom)

            if let s = session {
                SHPlayView(session: s,
                           onExit: { session = nil },
                           onReplace: { next in session = next })
                    .id(s.id)
            }

            if !store.data.onboardingDone {
                SHOnboardingView()
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(0, "Stack") { on in AnyView(SHIconCairn(size: 22, color: on ? SHTheme.slate : SHTheme.inkFaint)) }
            tabButton(1, "Gallery") { on in AnyView(SHIconGallery(size: 21, color: on ? SHTheme.slate : SHTheme.inkFaint)) }
            tabButton(2, "Stones") { on in AnyView(SHIconStone(size: 22, color: on ? SHTheme.slate : SHTheme.inkFaint)) }
            tabButton(3, "Settings") { on in AnyView(SHIconSliders(size: 21, color: on ? SHTheme.slate : SHTheme.inkFaint)) }
        }
        .padding(.top, 8)
        .padding(.bottom, max(6, SHSafe.bottom))
        .background(
            SHTheme.card
                .overlay(SHTheme.hairline.frame(height: 1), alignment: .top)
                .edgesIgnoringSafeArea(.bottom)
        )
    }

    private func tabButton(_ index: Int, _ label: String,
                           _ icon: @escaping (Bool) -> AnyView) -> some View {
        Button(action: {
            tab = index
            SHHaptics.tap(store.data.haptics)
        }) {
            VStack(spacing: 3) {
                icon(tab == index)
                    .frame(height: 24)
                Text(label)
                    .font(SHTheme.label(10, tab == index ? .semibold : .regular))
                    .foregroundColor(tab == index ? SHTheme.slate : SHTheme.inkFaint)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
