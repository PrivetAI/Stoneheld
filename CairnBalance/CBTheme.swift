import SwiftUI

// MARK: - Cold-shore palette (forced light, never follows the device theme)

enum CBTheme {
    // Core
    static let fog = Color(red: 0.851, green: 0.839, blue: 0.812)        // #D9D6CF
    static let slate = Color(red: 0.290, green: 0.322, blue: 0.349)      // #4A5259
    static let moss = Color(red: 0.486, green: 0.549, blue: 0.416)       // #7C8C6A
    static let driftwood = Color(red: 0.561, green: 0.478, blue: 0.369)  // #8F7A5E
    static let seaglass = Color(red: 0.435, green: 0.659, blue: 0.627)   // #6FA8A0
    static let ink = Color(red: 0.133, green: 0.157, blue: 0.173)        // #22282C
    static let rust = Color(red: 0.706, green: 0.396, blue: 0.247)       // #B4653F

    // Derived surfaces
    static let paper = Color(red: 0.925, green: 0.918, blue: 0.898)
    static let paperDeep = Color(red: 0.878, green: 0.867, blue: 0.839)
    static let card = Color(red: 0.965, green: 0.961, blue: 0.949)
    static let cardEdge = Color(red: 0.784, green: 0.773, blue: 0.749)
    static let inkSoft = Color(red: 0.133, green: 0.157, blue: 0.173).opacity(0.62)
    static let inkFaint = Color(red: 0.133, green: 0.157, blue: 0.173).opacity(0.32)
    static let hairline = Color(red: 0.133, green: 0.157, blue: 0.173).opacity(0.12)

    // Stone tints (hand-picked, all drawn from the shore palette)
    static let stoneTints: [Color] = [
        Color(red: 0.451, green: 0.482, blue: 0.502),   // wet slate
        Color(red: 0.576, green: 0.596, blue: 0.596),   // pale grey
        Color(red: 0.369, green: 0.404, blue: 0.435),   // deep slate
        Color(red: 0.522, green: 0.549, blue: 0.482),   // slate moss
        Color(red: 0.612, green: 0.588, blue: 0.529),   // dry shingle
        Color(red: 0.486, green: 0.443, blue: 0.380),   // driftwood grey
        Color(red: 0.400, green: 0.494, blue: 0.478),   // sea glass deep
        Color(red: 0.667, green: 0.647, blue: 0.612),   // bleached
        Color(red: 0.286, green: 0.310, blue: 0.333),   // basalt
        Color(red: 0.545, green: 0.510, blue: 0.443)    // river tan
    ]

    // Fonts
    static func display(_ size: CGFloat) -> Font { .custom("Georgia", size: size) }
    static func displayBold(_ size: CGFloat) -> Font { .custom("Georgia-Bold", size: size) }
    static func label(_ size: CGFloat, _ w: Font.Weight = .medium) -> Font {
        .system(size: size, weight: w, design: .default)
    }
    static func mono(_ size: CGFloat) -> Font { .custom("Menlo", size: size) }
    static func monoBold(_ size: CGFloat) -> Font { .custom("Menlo-Bold", size: size) }

    /// Green -> amber -> rust ramp used by the balance meter.
    static func marginColor(_ m: Double) -> Color {
        if !m.isFinite { return inkFaint }
        if m <= 0 { return rust }
        if m < 0.22 { return rust }
        if m < 0.48 { return Color(red: 0.780, green: 0.596, blue: 0.278) }
        return moss
    }
}

// MARK: - Safe area helper (custom UI hides every nav bar, so we own the strip)

enum CBSafe {
    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })
    }
    static var top: CGFloat { keyWindow?.safeAreaInsets.top ?? 20 }
    static var bottom: CGFloat { keyWindow?.safeAreaInsets.bottom ?? 0 }
    static var screen: CGSize { UIScreen.main.bounds.size }
    static var isShort: Bool { UIScreen.main.bounds.height < 700 }
}

// MARK: - Background

struct CBBackground: View, Equatable {
    var body: some View {
        ZStack {
            CBTheme.paper
            LinearGradient(
                colors: [Color.white.opacity(0.42), Color.clear, CBTheme.slate.opacity(0.07)],
                startPoint: .top, endPoint: .bottom)
            CBGrainOverlay()
                .equatable()
                .opacity(0.5)
        }
        .ignoresSafeArea()
    }
}

/// Deterministic sand-grain speckle drawn on a Canvas (no image assets).
struct CBGrainOverlay: View, Equatable {
    var body: some View {
        Canvas { ctx, size in
            var s: UInt64 = 0x9E3779B97F4A7C15
            let count = 280
            for _ in 0..<count {
                s = s &* 6364136223846793005 &+ 1442695040888963407
                let a = Double((s >> 33) & 0xFFFF) / 65535.0
                s = s &* 6364136223846793005 &+ 1442695040888963407
                let b = Double((s >> 33) & 0xFFFF) / 65535.0
                s = s &* 6364136223846793005 &+ 1442695040888963407
                let c = Double((s >> 33) & 0xFFFF) / 65535.0
                let r = 0.5 + c * 1.1
                let rect = CGRect(x: a * size.width, y: b * size.height, width: r, height: r)
                ctx.fill(Path(ellipseIn: rect), with: .color(CBTheme.slate.opacity(0.10 + c * 0.10)))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Cards & chrome

struct CBCard: ViewModifier {
    var pad: CGFloat = 16
    var radius: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .padding(pad)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(CBTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(CBTheme.cardEdge, lineWidth: 1)
            )
    }
}

extension View {
    func cbCard(pad: CGFloat = 16, radius: CGFloat = 14) -> some View {
        modifier(CBCard(pad: pad, radius: radius))
    }
}

/// The opaque strip that keeps scrolled content off the clock (custom UI = no nav bar).
struct CBStatusStrip: View {
    var body: some View {
        VStack(spacing: 0) {
            CBTheme.paper
                .frame(height: CBSafe.top)
                .overlay(CBTheme.hairline.frame(height: 1), alignment: .bottom)
            Spacer(minLength: 0)
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}

struct CBScreenTitle: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(CBTheme.display(27))
                .foregroundColor(CBTheme.ink)
            if let s = subtitle {
                Text(s)
                    .font(CBTheme.label(13, .regular))
                    .foregroundColor(CBTheme.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CBSectionHeader: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(CBTheme.label(11, .semibold))
            .tracking(1.4)
            .foregroundColor(CBTheme.inkFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CBPill: View {
    let text: String
    var color: Color = CBTheme.slate
    var body: some View {
        Text(text)
            .font(CBTheme.label(11, .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(color.opacity(0.12))
            )
    }
}

struct CBWideButton: View {
    let title: String
    var tone: Color = CBTheme.slate
    var enabled: Bool = true
    let action: () -> Void
    var body: some View {
        Button(action: { if enabled { action() } }) {
            Text(title)
                .font(CBTheme.label(15, .semibold))
                .foregroundColor(enabled ? Color.white : CBTheme.inkFaint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(enabled ? tone : CBTheme.paperDeep)
                )
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct CBGhostButton: View {
    let title: String
    var tone: Color = CBTheme.slate
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(CBTheme.label(14, .semibold))
                .foregroundColor(tone)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(tone.opacity(0.45), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Haptics

enum CBHaptics {
    static func tap(_ enabled: Bool) {
        guard enabled else { return }
        let g = UIImpactFeedbackGenerator(style: .light)
        g.impactOccurred()
    }
    static func seat(_ enabled: Bool) {
        guard enabled else { return }
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.impactOccurred()
    }
    static func fall(_ enabled: Bool) {
        guard enabled else { return }
        let g = UIImpactFeedbackGenerator(style: .heavy)
        g.impactOccurred()
    }
}

// MARK: - Formatting

enum CBFormat {
    private static let posix = Locale(identifier: "en_US_POSIX")

    static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = posix
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let prettyDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = posix
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    static let shortDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = posix
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "d MMM"
        return f
    }()

    static func height(_ v: Double) -> String {
        guard v.isFinite else { return "—" }
        return String(format: "%.0f", max(0, v))
    }

    static func margin(_ v: Double) -> String {
        guard v.isFinite else { return "—" }
        return String(format: "%.0f%%", v * 100)
    }

    static func int(_ v: Int) -> String { "\(v)" }
}
