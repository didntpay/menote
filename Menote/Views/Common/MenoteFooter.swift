import SwiftUI

/// Shared "Import audio · Settings" footer row.
///
/// Two surfaces show this — the menu-bar dropdown and the main-window sidebar.
/// They differ only in whether the buttons show SF Symbols next to the labels;
/// pick a `style` per surface.
struct MenoteFooter: View {

    enum Style {
        /// Text-only — used in the compact menu-bar dropdown.
        case compact
        /// `Label` with leading SF Symbols — used in the sidebar footer.
        case labeled
    }

    let style: Style
    let onImport: () -> Void

    var body: some View {
        HStack(spacing: hStackSpacing) {
            if needsBookendSpacers { Spacer() }

            Button(action: onImport) {
                content(text: importLabel, systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.plain)
            .help("Run an audio file (mp3, m4a, wav…) through the transcribe → notes pipeline.")

            Text("·")
                .font(AppTheme.bodySmall)
                .foregroundColor(AppTheme.textTertiary)

            SettingsLink {
                content(text: "Settings", systemImage: "gearshape")
            }
            .buttonStyle(.plain)

            if needsBookendSpacers { Spacer() }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, verticalPadding)
    }

    // MARK: - Style-driven knobs
    //
    // Kept as computed properties so `body` reads linearly instead of
    // peppering ternaries through the layout.

    private var hStackSpacing: CGFloat {
        switch style {
        case .compact: return 14
        case .labeled: return 12
        }
    }

    private var verticalPadding: CGFloat {
        switch style {
        case .compact: return 8
        case .labeled: return 10
        }
    }

    /// `.labeled` is sidebar chrome — the `Spacer`s on either side center the
    /// pair inside the full sidebar width. `.compact` lives in a tight popover
    /// and centers via its parent already.
    private var needsBookendSpacers: Bool {
        style == .labeled
    }

    /// Compact gets the full phrase since there's no icon to anchor the word;
    /// labeled pairs with an SF Symbol and can be terser.
    private var importLabel: String {
        switch style {
        case .compact: return "Import audio…"
        case .labeled: return "Import"
        }
    }

    @ViewBuilder
    private func content(text: String, systemImage: String) -> some View {
        switch style {
        case .compact:
            Text(text)
                .font(AppTheme.bodySmall)
                .foregroundColor(AppTheme.textSecondary)
        case .labeled:
            Label(text, systemImage: systemImage)
                .font(AppTheme.bodySmall)
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}

#Preview("Footer — labeled (sidebar)") {
    MenoteFooter(style: .labeled, onImport: {})
        .frame(width: 240)
        .background(AppTheme.sidebar)
}

#Preview("Footer — compact (dropdown)") {
    MenoteFooter(style: .compact, onImport: {})
        .frame(width: AppTheme.dropdownWidth)
        .background(AppTheme.background)
}
