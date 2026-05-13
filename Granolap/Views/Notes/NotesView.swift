import SwiftUI

struct NotesView: View {
    @ObservedObject var controller: NotesController
    @State private var keyPointsExpanded = false
    @State private var transcriptExpanded = false

    var body: some View {
        ScrollView {
            if let meeting = controller.selectedMeeting, let notes = controller.notes {
                VStack(alignment: .leading, spacing: 0) {
                    NoteHeader(meeting: meeting, notes: notes)

                    Divider().overlay(AppTheme.border).padding(.horizontal, AppTheme.padding)

                    ActionItemsSection(
                        items: notes.actionItems,
                        onToggle: { controller.toggleActionItem(id: $0) }
                    )

                    Divider().overlay(AppTheme.border).padding(.horizontal, AppTheme.padding)

                    SummarySection(text: notes.summary)

                    Divider().overlay(AppTheme.borderDashed).padding(.horizontal, AppTheme.padding)

                    CollapsibleSection(
                        title: "Key points",
                        badge: "\(notes.keyPoints.count)",
                        isExpanded: $keyPointsExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(notes.keyPoints.enumerated()), id: \.offset) { _, pt in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("·").foregroundColor(AppTheme.textTertiary)
                                    Text(pt).font(AppTheme.body).foregroundColor(AppTheme.text)
                                }
                            }
                        }
                        .padding(.horizontal, AppTheme.padding)
                        .padding(.bottom, AppTheme.padding)
                    }

                    if let transcript = controller.transcript {
                        Divider().overlay(AppTheme.borderDashed).padding(.horizontal, AppTheme.padding)
                        CollapsibleSection(
                            title: "Transcript",
                            badge: meeting.formattedDuration,
                            isExpanded: $transcriptExpanded
                        ) {
                            TranscriptSection(segments: transcript.segments)
                        }
                    }
                }
            } else {
                Text("No meeting selected")
                    .font(AppTheme.body)
                    .foregroundColor(AppTheme.textTertiary)
                    .padding(40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .paperBackground()
    }
}

// MARK: - Sub-views (pure display, zero business logic)

#Preview("Notes — with meeting") {
    let c = NotesController(
        meeting: MeetingRecord(
            id: "1", title: "Q2 Roadmap Review",
            startedAt: .init(timeIntervalSinceNow: -3600), durationSeconds: 2538,
            audioPath: "", transcriptPath: "", notesPath: ""
        ),
        notes: NotesData(
            title: "Q2 Roadmap Review",
            summary: "The team aligned on shipping the notes editor in the next sprint. Diarization was pushed to v1.2.",
            keyPoints: ["Editor blocked on schema migration", "WhisperKit small.en gives acceptable accuracy"],
            actionItems: [
                ActionItem(text: "Share onboarding spec", owner: "Maya", due: "by Tue", done: false),
                ActionItem(text: "Scope migration ticket", owner: "Ravi", due: "this sprint", done: false),
                ActionItem(text: "Schedule follow-up", owner: nil, due: nil, done: true)
            ]
        ),
        transcript: TranscriptData(language: "en", segments: [
            TranscriptSegment(start: 0, end: 4.2, text: "Thanks everyone for joining.", speakerId: nil),
            TranscriptSegment(start: 4.2, end: 9.8, text: "Let's kick off with the roadmap.", speakerId: nil)
        ])
    )
    return NotesView(controller: c)
}

private struct NoteHeader: View {
    let meeting: MeetingRecord
    let notes: NotesData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(notes.title)
                .font(AppTheme.headingFont(size: 24))
                .foregroundColor(AppTheme.text)
            HStack(spacing: 6) {
                Text(meeting.formattedDate)
                Text("·")
                Text(meeting.formattedDuration)
                let open = notes.actionItems.filter { !$0.done }.count
                if open > 0 { Text("·"); Text("\(open) to do") }
            }
            .font(AppTheme.mono)
            .foregroundColor(AppTheme.textTertiary)
        }
        .padding(AppTheme.padding)
    }
}

private struct ActionItemsSection: View {
    let items: [ActionItem]
    let onToggle: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Action items").font(AppTheme.body.weight(.semibold))
                Spacer()
                let done = items.filter(\.done).count
                Text("\(done) of \(items.count)")
                    .font(AppTheme.monoSmall)
                    .foregroundColor(AppTheme.textTertiary)
            }
            .padding(.horizontal, AppTheme.padding)
            .padding(.vertical, 12)

            ForEach(items) { item in
                HStack(alignment: .top, spacing: 10) {
                    Button { onToggle(item.id) } label: {
                        Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(item.done ? AppTheme.doneGreen : AppTheme.border)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.text)
                            .font(AppTheme.body)
                            .foregroundColor(item.done ? AppTheme.textSecondary : AppTheme.text)
                            .strikethrough(item.done, color: AppTheme.textTertiary)
                        HStack(spacing: 6) {
                            if let o = item.owner { Text(o) }
                            if let d = item.due   { Text("·"); Text(d) }
                        }
                        .font(AppTheme.monoSmall)
                        .foregroundColor(AppTheme.textTertiary)
                    }
                    Spacer()
                }
                .padding(.horizontal, AppTheme.padding)
                .padding(.vertical, 7)
            }
        }
    }
}

private struct SummarySection: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary").font(AppTheme.body.weight(.semibold))
            Text(text).font(AppTheme.body).foregroundColor(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppTheme.padding)
    }
}

private struct TranscriptSection: View {
    let segments: [TranscriptSegment]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                HStack(alignment: .top, spacing: 10) {
                    Text(formatTime(seg.start))
                        .font(AppTheme.monoSmall)
                        .foregroundColor(AppTheme.textTertiary)
                        .frame(width: 38, alignment: .trailing)
                    Text(seg.text)
                        .font(AppTheme.bodySmall)
                        .foregroundColor(AppTheme.text)
                }
            }
        }
        .padding(.horizontal, AppTheme.padding)
        .padding(.bottom, AppTheme.padding)
    }

    private func formatTime(_ s: Double) -> String {
        String(format: "%d:%02d", Int(s) / 60, Int(s) % 60)
    }
}

private struct CollapsibleSection<Content: View>: View {
    let title: String
    let badge: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppTheme.textTertiary)
                    Text(title).font(AppTheme.body.weight(.semibold))
                    Spacer()
                    Text(badge).font(AppTheme.monoSmall).foregroundColor(AppTheme.textTertiary)
                }
                .padding(.horizontal, AppTheme.padding)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            if isExpanded { content() }
        }
    }
}
