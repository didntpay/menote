import SwiftUI

// Reference view — actual status bar text is rendered by StatusBarController.
// Open this file in Xcode and hit ⌘⌥↩ to see the canvas.
struct GenerationPillView: View {
    let stage: String
    let progress: Double

    var body: some View {
        HStack(spacing: 6) {
            ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
            Text("\(stage) · \(Int(progress * 100))%")
                .font(AppTheme.monoSmall)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(AppTheme.surface)
        .cornerRadius(10)
        .paperBorder()
    }
}

#Preview("Pill — transcribing") {
    GenerationPillView(stage: "transcribing", progress: 0.4)
        .padding()
        .background(Color(hex: "#faf9f5"))
}

#Preview("Pill — writing notes") {
    GenerationPillView(stage: "writing notes", progress: 0.75)
        .padding()
        .background(Color(hex: "#faf9f5"))
}
