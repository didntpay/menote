import SwiftUI

struct NotesView: View {
    @ObservedObject var controller: NotesController

    var body: some View {
        ScrollView {
            if let meeting = controller.selectedMeeting, let notes = controller.notes {
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 24) {
                        NoteHeader(meeting: meeting, notes: notes)
                        ActionItemsCard(
                            items: notes.actionItems,
                            onToggle: { controller.toggleActionItem(id: $0) }
                        )
                        SummarySection(text: notes.summary)
                        if !notes.keyPoints.isEmpty {
                            KeyPointsSection(points: notes.keyPoints)
                        }
                    }
                    .frame(maxWidth: 720, alignment: .leading)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 32)
            } else {
                Text("No meeting selected")
                    .font(AppTheme.body)
                    .foregroundColor(AppTheme.textTertiary)
                    .padding(40)
            }
        }
        .background(AppTheme.background)
    }
}

// MARK: - Header

private struct NoteHeader: View {
    let meeting: MeetingRecord
    let notes: NotesData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(notes.title)
                .font(AppTheme.titleFont(size: 30))
                .foregroundColor(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 14) {
                Text(meeting.formattedMetaDate)
                Text(meeting.formattedMinutes)

                let open = notes.actionItems.filter { !$0.done }.count
                if open > 0 {
                    Pill(text: "\(open) action item\(open == 1 ? "" : "s")")
                }
            }
            .font(AppTheme.bodySmall)
            .foregroundColor(AppTheme.textSecondary)
        }
    }
}

// MARK: - Action items card

private struct ActionItemsCard: View {
    let items: [ActionItem]
    let onToggle: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textSecondary)
                Text("Action items")
                    .font(AppTheme.bodySemibold)
                    .foregroundColor(AppTheme.text)
                Spacer()
                let done = items.filter(\.done).count
                Text("\(done) of \(items.count) done")
                    .font(AppTheme.monoSmall)
                    .foregroundColor(AppTheme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().overlay(AppTheme.border)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    ActionItemRow(item: item, onToggle: { onToggle(item.id) })
                    if idx < items.count - 1 {
                        Divider().overlay(AppTheme.border.opacity(0.6))
                            .padding(.leading, 46)
                    }
                }
            }
        }
        .card()
    }
}

private struct ActionItemRow: View {
    let item: ActionItem
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CheckboxButton(isOn: item.done, action: onToggle)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.text)
                    .font(AppTheme.bodyMedium)
                    .foregroundColor(item.done ? AppTheme.textTertiary : AppTheme.text)
                    .strikethrough(item.done, color: AppTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                let meta = [item.owner, item.due].compactMap { $0 }
                if !meta.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(meta.enumerated()), id: \.offset) { i, str in
                            if i > 0 { Text("·") }
                            Text(str)
                        }
                    }
                    .font(AppTheme.bodySmall)
                    .foregroundColor(AppTheme.textTertiary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct CheckboxButton: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(isOn ? AppTheme.text : AppTheme.borderStrong, lineWidth: 1.4)
                    .frame(width: 18, height: 18)
                if isOn {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppTheme.text)
                        .frame(width: 18, height: 18)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Summary

private struct SummarySection: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Summary")
            Text(text)
                .font(AppTheme.body)
                .foregroundColor(AppTheme.text)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Key points

private struct KeyPointsSection: View {
    let points: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Key points")
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    HStack(alignment: .top, spacing: 10) {
                        Text("•")
                            .foregroundColor(AppTheme.textTertiary)
                        Text(point)
                            .font(AppTheme.body)
                            .foregroundColor(AppTheme.text)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Notes — full") {
    let c = NotesController(
        meeting: MeetingRecord(
            id: "1", title: "Roadmap review · Q2",
            startedAt: .init(timeIntervalSinceNow: -3600), durationSeconds: 2538,
            audioPath: "", transcriptPath: "", notesPath: ""
        ),
        notes: NotesData(
            title: "Roadmap review · Q2",
            summary: "The team aligned on onboarding rewrite as Q2's top priority. Engineering needs about three weeks of migration runway before screen work can start; Maya will own the spec and circulate it by Tuesday. A follow-up review is scheduled for May 28 to confirm scope.",
            keyPoints: [
                "Onboarding rewrite is the Q2 priority — must ship before July",
                "Engineering needs ~3 weeks of migration runway before screens",
                "Maya owns the onboarding spec; due Tuesday"
            ],
            actionItems: [
                ActionItem(text: "Share onboarding spec", owner: "Maya", due: "by Tue", done: false),
                ActionItem(text: "Scope migration ticket", owner: "Ravi", due: "this sprint", done: false),
                ActionItem(text: "Schedule follow-up review", owner: "auto", due: "invite sent", done: true)
            ]
        ),
        transcript: nil
    )
    return NotesView(controller: c)
        .frame(width: 760, height: 720)
}
