import AVFoundation
import Foundation

// Captures mic audio via AVAudioRecorder.
// System audio (ScreenCaptureKit/SCStream) is a future addition.
@MainActor
final class AudioCaptureManager: NSObject, ObservableObject {

    @Published var micLevel: Float = -60   // dBFS, range roughly -60…0
    @Published var isRecording = false
    @Published var isPaused = false

    private var recorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private(set) var currentSessionDir: URL?
    private(set) var audioURL: URL?

    // MARK: - Lifecycle

    func startCapture(sessionDir: URL) throws {
        let url = sessionDir.appendingPathComponent("mic.m4a")
        audioURL = url
        currentSessionDir = sessionDir

        let settings: [String: Any] = [
            AVFormatIDKey:            Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey:          44100.0,
            AVNumberOfChannelsKey:    1,
            AVEncoderBitRateKey:      96_000
        ]
        let rec = try AVAudioRecorder(url: url, settings: settings)
        rec.isMeteringEnabled = true
        rec.delegate = self
        guard rec.record() else { throw CaptureError.recordFailed }
        recorder = rec
        isRecording = true
        isPaused = false
        startLevelTimer()
    }

    func pause() {
        recorder?.pause()
        isPaused = true
        levelTimer?.invalidate()
        micLevel = -60
    }

    func resume() {
        recorder?.record()
        isPaused = false
        startLevelTimer()
    }

    func stop() -> URL? {
        levelTimer?.invalidate()
        recorder?.stop()
        recorder = nil
        isRecording = false
        isPaused = false
        micLevel = -60
        return audioURL
    }

    // MARK: - Level metering

    private func startLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.recorder?.updateMeters()
            let raw = self.recorder?.averagePower(forChannel: 0) ?? -60
            // Clamp to displayable range
            self.micLevel = max(-60, min(0, raw))
        }
    }

    enum CaptureError: LocalizedError {
        case recordFailed
        var errorDescription: String? { "Could not start audio recording." }
    }
}

extension AudioCaptureManager: AVAudioRecorderDelegate {
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error { print("AudioCaptureManager encode error: \(error)") }
    }
}
