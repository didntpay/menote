import SwiftUI

struct RecorderView: View {
    @ObservedObject var controller: AppController

    private var recorder: RecorderController { controller.recorder }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Red = End
                TrafficLight(color: AppTheme.recordingRed, symbol: "xmark") {
                    controller.endRecording()
                }
                // Yellow = Pause / Resume
                TrafficLight(color: AppTheme.pauseYellow, symbol: isPaused ? "play" : "pause") {
                    isPaused ? controller.resumeRecording() : controller.pauseRecording()
                }

                Spacer()

                Text(recorder.state.elapsed.formattedElapsed)
                    .font(AppTheme.mono)
                    .foregroundColor(AppTheme.text)

                if isPaused {
                    Text("paused")
                        .font(AppTheme.monoSmall)
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            Spacer()

            HStack(spacing: 16) {
                AudioMeter(icon: "mic",            level: recorder.audio.micLevel, color: AppTheme.recordingRed)
                AudioMeter(icon: "speaker.wave.2", level: -60,                     color: AppTheme.actionBlue)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .frame(width: AppTheme.recorderWidth, height: AppTheme.recorderHeight)
        .paperBackground()
    }

    private var isPaused: Bool {
        if case .paused = recorder.state { return true }
        return false
    }
}

#Preview("Recorder — recording") {
    RecorderView(controller: AppController())
        .frame(width: AppTheme.recorderWidth, height: AppTheme.recorderHeight)
}

private struct TrafficLight: View {
    let color: Color
    let symbol: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(color).frame(width: 12, height: 12)
                if hovered {
                    Image(systemName: symbol)
                        .font(.system(size: 6, weight: .black))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

private struct AudioMeter: View {
    let icon: String
    let level: Float   // dBFS −60…0
    let color: Color
    private let bars = 10

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(AppTheme.textTertiary)
                .frame(width: 14)
            HStack(spacing: 2) {
                ForEach(0..<bars, id: \.self) { i in
                    let threshold = Float(i) / Float(bars)
                    let normalized = (level + 60) / 60
                    RoundedRectangle(cornerRadius: 1)
                        .fill(normalized > threshold ? color : AppTheme.border)
                        .frame(width: 4, height: 10)
                }
            }
        }
    }
}
