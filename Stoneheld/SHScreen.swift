import SwiftUI

/// Shared scaffold: paper background, top strip that keeps content off the
/// clock, and a bottom inset that clears the floating tab bar (the padding lives
/// here so pushed screens inherit it too).
struct SHScreen<Content: View>: View {
    var spacing: CGFloat = 14
    let content: Content

    init(spacing: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            SHBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: spacing) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, SHSafe.top + 10)
                .padding(.bottom, SHTabBar.height + SHSafe.bottom + 26)
            }
            SHStatusStrip()
        }
        .navigationBarHidden(true)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SHBackRow: View {
    var label: String = "Back"
    @Environment(\.presentationMode) private var presentation
    var body: some View {
        HStack(spacing: 8) {
            Button(action: { presentation.wrappedValue.dismiss() }) {
                HStack(spacing: 5) {
                    SHIconChevron(size: 13, color: SHTheme.slate, pointsLeft: true)
                    Text(label)
                        .font(SHTheme.label(13, .semibold))
                        .foregroundColor(SHTheme.slate)
                }
                .padding(.vertical, 6)
                .padding(.trailing, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
    }
}

/// A row that behaves like a list item but is built entirely from our own parts.
struct SHRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var tint: Color = SHTheme.ink
    let trailing: Trailing
    var action: (() -> Void)? = nil

    init(title: String, subtitle: String? = nil, tint: Color = SHTheme.ink,
         action: (() -> Void)? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
        self.action = action
        self.trailing = trailing()
    }

    var body: some View {
        let inner = HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SHTheme.label(14, .semibold))
                    .foregroundColor(tint)
                    .multilineTextAlignment(.leading)
                if let s = subtitle {
                    Text(s)
                        .font(SHTheme.label(11, .regular))
                        .foregroundColor(SHTheme.inkSoft)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 6)
            trailing
        }
        .contentShape(Rectangle())

        if let a = action {
            Button(action: a) { inner }.buttonStyle(.plain)
        } else {
            inner
        }
    }
}

enum SHTabBar {
    static let height: CGFloat = 58
}
