import Foundation

protocol NotesGenerator {
    func generateNotes(from transcript: TranscriptData) async throws -> NotesData
}

enum GeneratorError: LocalizedError {
    case missingAPIKey
    case httpError(Int)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:     return "No Anthropic API key — add one in Settings."
        case .httpError(let c): return "Claude API returned HTTP \(c)."
        case .invalidResponse(let d): return "Unexpected response: \(d)"
        }
    }
}
