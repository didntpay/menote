import Foundation

// Owns notes reading and local edits. Knows nothing about UI.
@MainActor
final class NotesController: ObservableObject {

    @Published private(set) var selectedMeeting: MeetingRecord?
    @Published private(set) var notes: NotesData?
    @Published private(set) var transcript: TranscriptData?

    private let store: MeetingStore

    init(store: MeetingStore) {
        self.store = store
    }

    // Convenience init for SwiftUI previews — bypasses disk.
    init(meeting: MeetingRecord, notes: NotesData, transcript: TranscriptData? = nil) {
        self.store = MeetingStore()
        self.selectedMeeting = meeting
        self.notes = notes
        self.transcript = transcript
    }

    func open(_ meeting: MeetingRecord) {
        selectedMeeting = meeting
        notes = try? store.loadNotes(for: meeting)
        transcript = try? store.loadTranscript(for: meeting)
    }

    func toggleActionItem(id: String) {
        guard let meeting = selectedMeeting else { return }
        try? store.toggleActionItem(meetingID: meeting.id, itemID: id)
        notes = try? store.loadNotes(for: meeting)
    }

    func clear() {
        selectedMeeting = nil
        notes = nil
        transcript = nil
    }

}
