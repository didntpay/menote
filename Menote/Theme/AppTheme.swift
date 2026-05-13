import SwiftUI

enum AppTheme {
    // MARK: - Colors
    static let background     = Color(hex: "#faf9f5")
    static let surface        = Color(hex: "#f3f1ea")
    static let border         = Color(hex: "#d4cfc0")
    static let borderDashed   = Color(hex: "#c8c3b4")
    static let text           = Color(hex: "#1a1814")
    static let textSecondary  = Color(hex: "#6b6558")
    static let textTertiary   = Color(hex: "#9a9388")
    static let recordingRed   = Color(hex: "#c0392b")
    static let pauseYellow    = Color(hex: "#e67e22")
    static let doneGreen      = Color(hex: "#27ae60")
    static let actionBlue     = Color(hex: "#2980b9")

    // MARK: - Typography
    static func headingFont(size: CGFloat = 22) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    static let body     = Font.system(size: 14)
    static let bodySmall = Font.system(size: 12)
    static let mono     = Font.system(size: 12, design: .monospaced)
    static let monoSmall = Font.system(size: 11, design: .monospaced)

    // MARK: - Geometry
    static let cornerRadius: CGFloat = 6
    static let padding: CGFloat = 16
    static let paddingSmall: CGFloat = 10
    static let dropdownWidth: CGFloat = 280
    static let recorderWidth: CGFloat = 280
    static let recorderHeight: CGFloat = 120
    static let notesWidth: CGFloat = 620
    static let notesHeight: CGFloat = 680
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

// MARK: - View modifiers

struct PaperBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.background)
    }
}

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
    func paperBackground() -> some View { modifier(PaperBackground()) }
    func paperBorder(dashed: Bool = false) -> some View { modifier(PaperBorder(dashed: dashed)) }
}
