import Foundation

// Simple JSON-file–backed store. SQLite (GRDB) can replace this later.
final class MeetingStore {

    private let appSupport: URL
    private let meetingsDir: URL
    private let indexURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Granolap")
        appSupport = base
        meetingsDir = base.appendingPathComponent("meetings")
        indexURL = base.appendingPathComponent("meetings.json")
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try? FileManager.default.createDirectory(at: meetingsDir, withIntermediateDirectories: true)
    }

    // MARK: - Session directory

    func newSessionDirectory() throws -> (id: String, url: URL) {
        let id = UUID().uuidString
        let url = meetingsDir.appendingPathComponent(id)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return (id, url)
    }

    // MARK: - Save

    func save(
        id: String,
        sessionDir: URL,
        audioURL: URL,
        transcript: TranscriptData,
        notes: NotesData,
        durationSeconds: Int,
        startedAt: Date
    ) throws -> MeetingRecord {
        let transcriptURL = sessionDir.appendingPathComponent("transcript.json")
        let notesURL      = sessionDir.appendingPathComponent("notes.json")

        try encoder.encode(transcript).write(to: transcriptURL)
        try encoder.encode(notes).write(to: notesURL)

        let record = MeetingRecord(
            id: id,
            title: notes.title,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            audioPath: relativePath(audioURL),
            transcriptPath: relativePath(transcriptURL),
            notesPath: relativePath(notesURL)
        )

        var index = loadIndex()
        index.insert(record, at: 0)
        saveIndex(index)
        return record
    }

    // MARK: - Fetch

    func fetchRecent(limit: Int = 5) -> [MeetingRecord] {
        Array(loadIndex().prefix(limit))
    }

    func loadNotes(for record: MeetingRecord) throws -> NotesData {
        let url = appSupport.appendingPathComponent(record.notesPath)
        let data = try Data(contentsOf: url)
        return try decoder.decode(NotesData.self, from: data)
    }

    func loadTranscript(for record: MeetingRecord) throws -> TranscriptData {
        let url = appSupport.appendingPathComponent(record.transcriptPath)
        let data = try Data(contentsOf: url)
        return try decoder.decode(TranscriptData.self, from: data)
    }

    // MARK: - Action item toggle

    func toggleActionItem(meetingID: String, itemID: String) throws {
        var index = loadIndex()
        guard let mi = index.firstIndex(where: { $0.id == meetingID }) else { return }
        let record = index[mi]
        var notes = try loadNotes(for: record)
        guard let ai = notes.actionItems.firstIndex(where: { $0.id == itemID }) else { return }
        notes.actionItems[ai].done.toggle()
        let notesURL = appSupport.appendingPathComponent(record.notesPath)
        try encoder.encode(notes).write(to: notesURL)
        index[mi].updatedAt = Date()
        saveIndex(index)
    }

    // MARK: - Helpers

    private func relativePath(_ url: URL) -> String {
        url.path.replacingOccurrences(of: appSupport.path + "/", with: "")
    }

    private func loadIndex() -> [MeetingRecord] {
        guard let data = try? Data(contentsOf: indexURL),
              let records = try? decoder.decode([MeetingRecord].self, from: data) else { return [] }
        return records
    }

    private func saveIndex(_ records: [MeetingRecord]) {
        try? encoder.encode(records).write(to: indexURL)
    }
}
