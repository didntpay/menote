import Foundation

// MARK: - Meeting index record (stored in meetings.json)

struct MeetingRecord: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var startedAt: Date
    var durationSeconds: Int
    var audioPath: String        // relative to app support dir
    var transcriptPath: String
    var notesPath: String
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var formattedDuration: String {
        let h = durationSeconds / 3600
        let m = (durationSeconds % 3600) / 60
        let s = durationSeconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: startedAt)
    }
}

// MARK: - Transcript

struct TranscriptData: Codable {
    var language: String
    var segments: [TranscriptSegment]

    var fullText: String {
        segments.map(\.text).joined(separator: " ")
    }
}

struct TranscriptSegment: Codable {
    var start: Double
    var end: Double
    var text: String
    var speakerId: String?
}

// MARK: - Notes

struct NotesData: Codable {
    var title: String
    var summary: String
    var keyPoints: [String]
    var actionItems: [ActionItem]
}

struct ActionItem: Codable, Identifiable {
    var id: String = UUID().uuidString
    var text: String
    var owner: String?
    var due: String?
    var done: Bool = false
    var externalRef: String?
}
