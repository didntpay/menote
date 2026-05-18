import Foundation
import WhisperKit

/// Local transcription via WhisperKit (Core ML / Neural Engine).
/// First call downloads the `small.en` model (~466MB); subsequent calls reuse the cached pipeline.
///
/// `@MainActor`-isolated so the cache + loading-task state never race across callers. The
/// async work inside (download/load/transcribe) suspends off-main as expected.
@MainActor
final class WhisperKitTranscriber: Transcriber {

    static let modelVariant = "openai_whisper-small.en"

    // Instance-local — single transcriber lives for the life of AppController.
    private var cached: WhisperKit?
    private var loadingTask: Task<WhisperKit, Error>?

    /// `(stage, progress 0…1)` — called during model download/load and transcription.
    var onProgress: (@MainActor (String, Double) -> Void)?

    func transcribe(audioURL: URL) async throws -> TranscriptData {
        let pipe = try await ensurePipeline()

        onProgress?("transcribing", 0.0)
        let results = try await pipe.transcribe(audioPath: audioURL.path)

        let segments: [TranscriptSegment] = results
            .flatMap { $0.segments }
            .map { seg in
                TranscriptSegment(
                    start: Double(seg.start),
                    end:   Double(seg.end),
                    text:  Self.cleanText(seg.text),
                    speakerId: nil
                )
            }
            .filter { !$0.text.isEmpty }

        guard !segments.isEmpty else {
            throw TranscriptionError.noAudio
        }

        let language = results.first?.language ?? "en"
        return TranscriptData(language: language, segments: segments)
    }

    // MARK: - Private

    private func ensurePipeline() async throws -> WhisperKit {
        if let cached { return cached }
        if let inflight = loadingTask { return try await inflight.value }

        let progress = onProgress
        let task = Task { @MainActor () -> WhisperKit in
            progress?("preparing model", 0.0)
            let folder = try await WhisperKit.download(
                variant: Self.modelVariant,
                progressCallback: { p in
                    Task { @MainActor in
                        progress?("downloading model", p.fractionCompleted)
                    }
                }
            )
            progress?("loading model", 0.98)
            let config = WhisperKitConfig(
                modelFolder: folder.path,
                verbose: false,
                logLevel: .error,
                prewarm: true,
                load: true,
                download: false
            )
            return try await WhisperKit(config)
        }
        loadingTask = task
        do {
            let pipe = try await task.value
            cached = pipe
            loadingTask = nil
            return pipe
        } catch {
            loadingTask = nil
            throw error
        }
    }

    /// Strips WhisperKit special tokens like `<|en|>`, `<|0.00|>`, `<|notimestamps|>`,
    /// `<|endoftext|>`, etc. from segment text.
    private static func cleanText(_ raw: String) -> String {
        let withoutTokens = raw.replacingOccurrences(
            of: #"<\|[^|]*\|>"#,
            with: "",
            options: .regularExpression
        )
        return withoutTokens.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum TranscriptionError: LocalizedError {
        case noAudio
        var errorDescription: String? {
            switch self {
            case .noAudio: return "No transcribable audio detected in the recording."
            }
        }
    }
}
