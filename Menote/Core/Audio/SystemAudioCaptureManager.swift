import AVFoundation
import ScreenCaptureKit
import CoreMedia

@MainActor
final class SystemAudioCaptureManager: NSObject, ObservableObject {

    enum Status { case idle, capturing, unavailable }

    @Published var systemLevel: Float = -60
    @Published private(set) var status: Status = .idle

    private var stream: SCStream?
    private(set) var audioURL: URL?

    // These are touched only on the SCStream sample-handler queue (serial),
    // so we mark them nonisolated(unsafe) and avoid main-thread hops per sample.
    nonisolated(unsafe) private var writer: AVAssetWriter?
    nonisolated(unsafe) private var input: AVAssetWriterInput?
    nonisolated(unsafe) private var sessionStarted = false
    nonisolated(unsafe) private var sampleCounter = 0

    func startCapture(sessionDir: URL) async throws {
        let url = sessionDir.appendingPathComponent("system.m4a")
        try? FileManager.default.removeItem(at: url)
        audioURL = url

        let assetWriter = try AVAssetWriter(outputURL: url, fileType: .m4a)
        let settings: [String: Any] = [
            AVFormatIDKey:         kAudioFormatMPEG4AAC,
            AVSampleRateKey:       48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey:   128_000
        ]
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        writerInput.expectsMediaDataInRealTime = true
        guard assetWriter.canAdd(writerInput) else { throw CaptureError.writerSetup }
        assetWriter.add(writerInput)
        self.writer = assetWriter
        self.input = writerInput
        self.sessionStarted = false
        self.sampleCounter = 0

        // `false` = include desktop windows (we want everything making sound).
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else { throw CaptureError.noDisplay }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48000
        config.channelCount = 2
        // SCStream requires a video output even for audio-only captures.
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))
        try await stream.startCapture()
        self.stream = stream
        self.status = .capturing
    }

    func stop() async -> URL? {
        try? await stream?.stopCapture()
        stream = nil
        input?.markAsFinished()
        if let writer {
            await writer.finishWriting()
        }
        let url = audioURL
        writer = nil
        input = nil
        sessionStarted = false
        status = .idle
        return url
    }

    enum CaptureError: LocalizedError {
        case noDisplay
        case writerSetup
        var errorDescription: String? {
            switch self {
            case .noDisplay:   return "No display available for system audio capture."
            case .writerSetup: return "Could not set up system audio writer."
            }
        }
    }
}

extension SystemAudioCaptureManager: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid,
              let writer, let input else { return }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if !sessionStarted {
            if writer.status == .unknown { writer.startWriting() }
            writer.startSession(atSourceTime: pts)
            sessionStarted = true
        }
        if input.isReadyForMoreMediaData {
            input.append(sampleBuffer)
        }

        // Throttle level updates: ~50 buffers/sec → publish every 5th = ~10 Hz.
        sampleCounter &+= 1
        if sampleCounter % 5 == 0, let level = Self.peakLevel(of: sampleBuffer) {
            Task { @MainActor in self.systemLevel = level }
        }
    }

    nonisolated private static func peakLevel(of buffer: CMSampleBuffer) -> Float? {
        guard let formatDesc = CMSampleBufferGetFormatDescription(buffer),
              let asbdPtr = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else {
            return nil
        }
        let asbd = asbdPtr.pointee
        // Only handle 32-bit float PCM (what SCStream delivers on modern macOS).
        guard asbd.mFormatID == kAudioFormatLinearPCM,
              asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0,
              asbd.mBitsPerChannel == 32,
              let dataBuffer = CMSampleBufferGetDataBuffer(buffer) else {
            return nil
        }

        var lengthAtOffset = 0, totalLength = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(
            dataBuffer,
            atOffset: 0,
            lengthAtOffsetOut: &lengthAtOffset,
            totalLengthOut: &totalLength,
            dataPointerOut: &dataPointer
        ) == kCMBlockBufferNoErr,
              let ptr = dataPointer else { return nil }

        let count = totalLength / MemoryLayout<Float>.size
        let floats = ptr.withMemoryRebound(to: Float.self, capacity: count) {
            UnsafeBufferPointer(start: $0, count: count)
        }
        var peak: Float = 0
        for v in floats { peak = max(peak, abs(v)) }
        guard peak > 0 else { return -60 }
        return max(-60, 20 * log10(peak))
    }
}
