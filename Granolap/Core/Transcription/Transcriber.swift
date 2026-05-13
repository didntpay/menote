import Foundation

protocol Transcriber {
    func transcribe(audioURL: URL) async throws -> TranscriptData
}
