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

    /// Long-form metadata date — "Sat, May 17 · 10:42 AM".
    var formattedMetaDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE, MMM d  ·  h:mm a"
        return fmt.string(from: startedAt)
    }

    /// Duration like "42 min" or "1h 5 min" for the metadata row.
    var formattedMinutes: String {
        let total = durationSeconds
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m) min" }
        return "\(max(m, 1)) min"
    }

    /// Right-aligned timestamp for sidebar rows — "9:30" for today, "Fri" this week,
    /// "May 10" otherwise.
    var sidebarTimestamp: String {
        let cal = Calendar.current
        let fmt = DateFormatter()
        if cal.isDateInToday(startedAt) {
            fmt.dateFormat = "h:mm"
            return fmt.string(from: startedAt)
        }
        if cal.isDate(startedAt, equalTo: Date(), toGranularity: .weekOfYear) {
            fmt.dateFormat = "EEE"
            return fmt.string(from: startedAt)
        }
        fmt.dateFormat = "MMM d"
        return fmt.string(from: startedAt)
    }
}

enum MeetingGroup: String, CaseIterable, Hashable {
    case today, thisWeek, earlier

    /// User-facing label. Routes through `NSLocalizedString` so future
    /// translations only need to drop in a `.strings` file.
    var localizedName: String {
        switch self {
        case .today:    return NSLocalizedString("Today",     comment: "Sidebar group: meetings from today")
        case .thisWeek: return NSLocalizedString("This Week", comment: "Sidebar group: meetings earlier this week")
        case .earlier:  return NSLocalizedString("Earlier",   comment: "Sidebar group: older meetings")
        }
    }
}

extension Array where Element == MeetingRecord {
    /// Groups meetings into Today / This Week / Earlier. Empty groups are omitted.
    var grouped: [(group: MeetingGroup, items: [MeetingRecord])] {
        let cal = Calendar.current
        let now = Date()
        var today: [MeetingRecord] = []
        var thisWeek: [MeetingRecord] = []
        var earlier: [MeetingRecord] = []
        for meeting in self {
            if cal.isDateInToday(meeting.startedAt) {
                today.append(meeting)
            } else if cal.isDate(meeting.startedAt, equalTo: now, toGranularity: .weekOfYear) {
                thisWeek.append(meeting)
            } else {
                earlier.append(meeting)
            }
        }
        var result: [(MeetingGroup, [MeetingRecord])] = []
        if !today.isEmpty    { result.append((.today, today)) }
        if !thisWeek.isEmpty { result.append((.thisWeek, thisWeek)) }
        if !earlier.isEmpty  { result.append((.earlier, earlier)) }
        return result
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

    enum CodingKeys: String, CodingKey {
        case id, text, owner, due, done, externalRef
    }

    init(id: String = UUID().uuidString, text: String, owner: String? = nil, due: String? = nil, done: Bool = false, externalRef: String? = nil) {
        self.id = id; self.text = text; self.owner = owner; self.due = due; self.done = done; self.externalRef = externalRef
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // `id` and `done` use `try?` because we want a property-default fallback,
        // not just "key missing" semantics — Claude's schema doesn't return them.
        self.id          = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.done        = (try? c.decode(Bool.self,   forKey: .done)) ?? false
        self.text        = try  c.decode(String.self, forKey: .text)
        self.owner       = try  c.decodeIfPresent(String.self, forKey: .owner)
        self.due         = try  c.decodeIfPresent(String.self, forKey: .due)
        self.externalRef = try  c.decodeIfPresent(String.self, forKey: .externalRef)
    }
}
