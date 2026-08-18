import SwiftUI

struct CBRootView: View {
    @ObservedObject var store = CBStore.shared
    @State private var tab = 0
    @State private var session: CBSession?

    var body: some View {
        ZStack {
            ZStack(alignment: .bottom) {
                Group {
                    switch tab {
                    case 0:
                        NavigationView { CBStackView(session: $session) }
                            .navigationViewStyle(StackNavigationViewStyle())
                    case 1:
                        NavigationView { CBGalleryView() }
                            .navigationViewStyle(StackNavigationViewStyle())
                    case 2:
                        NavigationView { CBStonesView() }
                            .navigationViewStyle(StackNavigationViewStyle())
                    default:
                        NavigationView { CBSettingsView() }
                            .navigationViewStyle(StackNavigationViewStyle())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                tabBar
            }
            .edgesIgnoringSafeArea(.bottom)

            if let s = session {
                CBPlayView(session: s,
                           onExit: { session = nil },
                           onReplace: { next in session = next })
                    .id(s.id)
            }

            if !store.data.onboardingDone {
                CBOnboardingView()
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(0, "Stack") { on in AnyView(CBIconCairn(size: 22, color: on ? CBTheme.slate : CBTheme.inkFaint)) }
            tabButton(1, "Gallery") { on in AnyView(CBIconGallery(size: 21, color: on ? CBTheme.slate : CBTheme.inkFaint)) }
            tabButton(2, "Stones") { on in AnyView(CBIconStone(size: 22, color: on ? CBTheme.slate : CBTheme.inkFaint)) }
            tabButton(3, "Settings") { on in AnyView(CBIconSliders(size: 21, color: on ? CBTheme.slate : CBTheme.inkFaint)) }
        }
        .padding(.top, 8)
        .padding(.bottom, max(6, CBSafe.bottom))
        .background(
            CBTheme.card
                .overlay(CBTheme.hairline.frame(height: 1), alignment: .top)
                .edgesIgnoringSafeArea(.bottom)
        )
    }

    private func tabButton(_ index: Int, _ label: String,
                           _ icon: @escaping (Bool) -> AnyView) -> some View {
        Button(action: {
            tab = index
            CBHaptics.tap(store.data.haptics)
        }) {
            VStack(spacing: 3) {
                icon(tab == index)
                    .frame(height: 24)
                Text(label)
                    .font(CBTheme.label(10, tab == index ? .semibold : .regular))
                    .foregroundColor(tab == index ? CBTheme.slate : CBTheme.inkFaint)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
