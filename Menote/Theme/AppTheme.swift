import SwiftUI

/// Design tokens for the Menote redesign.
/// Light mode only — see PLAN.md for the dark-mode roadmap.
enum AppTheme {

    // MARK: - Colors

    /// Content pane background — warm off-white cream.
    static let background      = Color(hex: "#FAF7F0")
    /// Sidebar background. Intentionally equal to `background` today for a unified
    /// canvas; kept as a separate token so we can diverge (e.g. tinted sidebar)
    /// without touching every call site.
    static let sidebar         = Color(hex: "#FAF7F0")
    /// Card surface — pure white sitting on the content background.
    static let card            = Color.white
    /// Subtle surfaces inside cards (e.g. row hover, inputs).
    static let surface         = Color(hex: "#F3EFE6")

    /// Hairline borders & dividers.
    static let border          = Color(hex: "#E8E3D5")
    static let borderStrong    = Color(hex: "#D9D2BF")

    /// Text — primary almost-black, secondary medium gray, tertiary light gray.
    static let text            = Color(hex: "#1A1814")
    static let textSecondary   = Color(hex: "#7B7468")
    static let textTertiary    = Color(hex: "#A09889")

    /// Accent peach used for the action-items pill.
    static let accentPillBg    = Color(hex: "#F4D7B5")
    static let accentPillText  = Color(hex: "#8C4F1F")

    /// Recording / status colors.
    static let recordingRed    = Color(hex: "#C0392B")
    static let pauseYellow     = Color(hex: "#E67E22")
    static let doneGreen       = Color(hex: "#27AE60")
    static let actionBlue      = Color(hex: "#2563EB")

    /// Selected sidebar row.
    static let rowSelected     = Color(hex: "#EAE4D2")

    // MARK: - Typography

    /// Used for the meeting title in the detail pane.
    static func titleFont(size: CGFloat = 30) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    /// Legacy alias — used by a couple of older views; routed to the new title font.
    static func headingFont(size: CGFloat = 22) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    /// Section labels (SUMMARY, KEY POINTS) — uppercase, tracked.
    static let sectionLabel    = Font.system(size: 11, weight: .semibold)

    /// Sidebar group headers (TODAY, THIS WEEK).
    static let groupHeader     = Font.system(size: 10, weight: .semibold)

    static let body            = Font.system(size: 14)
    static let bodyMedium      = Font.system(size: 14, weight: .medium)
    static let bodySemibold    = Font.system(size: 14, weight: .semibold)
    static let bodySmall       = Font.system(size: 12)
    static let mono            = Font.system(size: 12, design: .monospaced)
    static let monoSmall       = Font.system(size: 11, design: .monospaced)

    // MARK: - Geometry

    static let cornerRadius:    CGFloat = 8
    static let cardCornerRadius: CGFloat = 10
    static let padding:         CGFloat = 24
    static let paddingSmall:    CGFloat = 12
    static let sidebarWidth:    CGFloat = 240

    /// Vertical space reserved at the top of each pane so content clears the
    /// transparent macOS title bar (~28pt + a few pt of breathing room).
    static let titleBarReserve: CGFloat = 36

    static let recorderWidth:   CGFloat = 320
    static let recorderHeight:  CGFloat = 140
    static let dropdownWidth:   CGFloat = 280
    static let notesWidth:      CGFloat = 700
    static let notesHeight:     CGFloat = 600
}

// MARK: - Color hex init

extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

// MARK: - Reusable components

/// Section label component — uppercase, tracked, tertiary color.
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(AppTheme.sectionLabel)
            .tracking(0.8)
            .foregroundColor(AppTheme.textTertiary)
    }
}

/// Pill used for inline badges like "3 action items".
struct Pill: View {
    let text: String
    var background: Color = AppTheme.accentPillBg
    var foreground: Color = AppTheme.accentPillText

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(background)
            .foregroundColor(foreground)
            .clipShape(Capsule())
    }
}

// MARK: - View modifiers

/// Card surface — white background, hairline border, subtle shadow.
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

/// Legacy paper-background modifier; now just applies the new background color.
struct PaperBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(AppTheme.background)
    }
}

/// Legacy paper-border modifier; now a simple hairline border.
struct PaperBorder: ViewModifier {
    var dashed: Bool = false
    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .strokeBorder(
                    AppTheme.border,
                    style: dashed
                        ? StrokeStyle(lineWidth: 1, dash: [4, 3])
                        : StrokeStyle(lineWidth: 1)
                )
        )
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
    func paperBackground() -> some View { modifier(PaperBackground()) }
    func paperBorder(dashed: Bool = false) -> some View { modifier(PaperBorder(dashed: dashed)) }
}
