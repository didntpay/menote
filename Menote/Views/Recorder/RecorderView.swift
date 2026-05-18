import SwiftUI

struct RecorderView: View {
    @ObservedObject var controller: AppController
    @ObservedObject var recorder: RecorderController
    @ObservedObject var mic: AudioCaptureManager

    init(controller: AppController) {
        self.controller = controller
        self.recorder   = controller.recorder
        self.mic        = controller.recorder.audio
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                RecordingDot(active: !isPaused)
                Text(recorder.state.elapsed.formattedElapsed)
                    .font(.system(size: 22, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.text)
                if isPaused {
                    Text("paused")
                        .font(AppTheme.bodySmall)
                        .foregroundColor(AppTheme.textTertiary)
                }
                Spacer()
                CircleButton(symbol: isPaused ? "play.fill" : "pause.fill") {
                    isPaused ? controller.resumeRecording() : controller.pauseRecording()
                }
                CircleButton(symbol: "stop.fill", tint: AppTheme.recordingRed) {
                    controller.endRecording()
                }
            }

            AudioMeter(level: mic.micLevel)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: AppTheme.recorderWidth, height: AppTheme.recorderHeight)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    private var isPaused: Bool {
        if case .paused = recorder.state { return true }
        return false
    }
}

// MARK: - Recording dot (gentle pulse)

private struct RecordingDot: View {
    let active: Bool
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(AppTheme.recordingRed)
            .frame(width: 10, height: 10)
            .scaleEffect(active && pulse ? 1.0 : 0.85)
            .opacity(active && pulse ? 1.0 : 0.7)
            .onChange(of: active, initial: true) { _, isActive in
                if isActive {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) { pulse = false }
                }
            }
    }
}

// MARK: - Circular control button

private struct CircleButton: View {
    let symbol: String
    var tint: Color = AppTheme.text
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(hovered ? AppTheme.surface : Color.clear)
                    .frame(width: 28, height: 28)
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(tint)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - Audio meter (smooth bar)

private struct AudioMeter: View {
    let level: Float   // dBFS −60…0
    private let bars = 24

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 3) {
                ForEach(0..<bars, id: \.self) { i in
                    let threshold = Float(i) / Float(bars)
                    let normalized = max(0, min(1, (level + 60) / 60))
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(barColor(normalized: normalized, threshold: threshold))
                        .frame(maxWidth: .infinity)
                        .frame(height: barHeight(i: i))
                }
            }
            .frame(width: proxy.size.width)
        }
        .frame(height: 26)
    }

    private func barColor(normalized: Float, threshold: Float) -> Color {
        guard normalized > threshold else { return AppTheme.border }
        if threshold > 0.85 { return AppTheme.recordingRed }
        if threshold > 0.70 { return AppTheme.pauseYellow }
        return AppTheme.text.opacity(0.7)
    }

    private func barHeight(i: Int) -> CGFloat {
        // Slight middle-tall envelope so the meter has a soft waveform feel.
        let mid = Double(bars) / 2
        let t = abs(Double(i) - mid) / mid
        return CGFloat(20 - t * 8)
    }
}

#Preview("Recorder — recording") {
    RecorderView(controller: AppController())
        .padding(40)
        .background(AppTheme.background)
}
