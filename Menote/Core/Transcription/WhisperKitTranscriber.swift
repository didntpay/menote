import Foundation
import Speech

struct WhisperKitTranscriber: Transcriber {
    func transcribe(audioURL: URL) async throws -> TranscriptData {
        let status = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard status == .authorized else {
            throw TranscriptionError.notAuthorized
        }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            throw TranscriptionError.unavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = false

        return try await withCheckedThrowingContinuation { cont in
            recognizer.recognitionTask(with: request) { result, error in
                if let error { cont.resume(throwing: error); return }
                guard let result, result.isFinal else { return }

                let words = result.bestTranscription.segments
                var segments: [TranscriptSegment] = []
                let chunkSize = 15
                var i = 0
                while i < words.count {
                    let chunk = words[i..<min(i + chunkSize, words.count)]
                    let text = chunk.map(\.substring).joined(separator: " ")
                    let start = chunk.first!.timestamp
                    let end = (chunk.last.map { $0.timestamp + $0.duration }) ?? start
                    segments.append(TranscriptSegment(start: start, end: end, text: text, speakerId: nil))
                    i += chunkSize
                }

                if segments.isEmpty {
                    let full = result.bestTranscription.formattedString
                    segments = [TranscriptSegment(start: 0, end: 0, text: full, speakerId: nil)]
                }

                cont.resume(returning: TranscriptData(language: "en", segments: segments))
            }
        }
    }
}

private enum TranscriptionError: LocalizedError {
    case notAuthorized
    case unavailable

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Speech recognition permission was denied."
        case .unavailable:   return "Speech recognition is not available on this device."
        }
    }
}
