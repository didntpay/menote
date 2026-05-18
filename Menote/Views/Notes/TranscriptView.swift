import SwiftUI

struct TranscriptView: View {
    @ObservedObject var controller: NotesController

    var body: some View {
        ScrollView {
            if let transcript = controller.transcript {
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionLabel(text: "Transcript")
                        ForEach(Array(transcript.segments.enumerated()), id: \.offset) { _, seg in
                            HStack(alignment: .top, spacing: 14) {
                                Text(formatTime(seg.start))
                                    .font(AppTheme.monoSmall)
                                    .foregroundColor(AppTheme.textTertiary)
                                    .frame(width: 44, alignment: .trailing)
                                Text(seg.text)
                                    .font(AppTheme.body)
                                    .foregroundColor(AppTheme.text)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: 720, alignment: .leading)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 32)
            } else {
                Text("No transcript available.")
                    .font(AppTheme.body)
                    .foregroundColor(AppTheme.textTertiary)
                    .padding(40)
            }
        }
        .background(AppTheme.background)
    }

    private func formatTime(_ s: Double) -> String {
        let total = Int(s)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

#Preview("Transcript") {
    let c = NotesController(
        meeting: MeetingRecord(
            id: "1", title: "Roadmap review · Q2",
            startedAt: .init(), durationSeconds: 2538,
            audioPath: "", transcriptPath: "", notesPath: ""
        ),
        notes: NotesData(title: "Roadmap review · Q2", summary: "", keyPoints: [], actionItems: []),
        transcript: TranscriptData(language: "en", segments: [
            TranscriptSegment(start: 0,    end: 4.2,  text: "Thanks everyone for joining.", speakerId: nil),
            TranscriptSegment(start: 4.2,  end: 9.8,  text: "Let's kick off with the roadmap review.", speakerId: nil),
            TranscriptSegment(start: 9.8,  end: 18.0, text: "Maya is going to walk us through the onboarding spec first.", speakerId: nil)
        ])
    )
    return TranscriptView(controller: c)
        .frame(width: 760, height: 720)
}
