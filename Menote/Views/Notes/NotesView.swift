import SwiftUI

struct NotesView: View {
    @ObservedObject var controller: NotesController

    var body: some View {
        ScrollView {
            if let meeting = controller.selectedMeeting, let notes = controller.notes {
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 24) {
                        NoteHeader(meeting: meeting, notes: notes)
                        if let metrics = controller.metrics,
                           controller.metricsBannerDismissedFor != meeting.id {
                            MetricsBanner(
                                metrics: metrics,
                                imported: meeting.imported,
                                onDismiss: { controller.dismissMetricsBanner() }
                            )
                        }
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

// MARK: - Metrics banner

private struct MetricsBanner: View {
    let metrics: PipelineMetrics
    let imported: Bool
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "stopwatch")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textSecondary)
                Text(imported ? "Pipeline benchmark · imported audio" : "Pipeline benchmark")
                    .font(AppTheme.bodySemibold)
                    .foregroundColor(AppTheme.text)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppTheme.textTertiary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Dismiss")
            }

            HStack(spacing: 0) {
                Metric(label: "audio",      value: Self.format(metrics.audioDurationSeconds))
                Divider().frame(height: 28).overlay(AppTheme.border)
                Metric(label: "transcribe", value: Self.format(metrics.transcribeSeconds))
                Divider().frame(height: 28).overlay(AppTheme.border)
                Metric(label: "claude",     value: Self.format(metrics.notesSeconds))
                Divider().frame(height: 28).overlay(AppTheme.border)
                Metric(label: "total",      value: Self.format(metrics.totalSeconds))
                Divider().frame(height: 28).overlay(AppTheme.border)
                Metric(label: "realtime ×", value: String(format: "%.2f", metrics.realtimeFactor))
            }

            if let usage = metrics.tokenUsage {
                TokenRow(usage: usage)
            }

            if metrics.includedModelLoad {
                Text("Includes one-time Whisper model load — re-run for a steady-state number.")
                    .font(AppTheme.bodySmall)
                    .foregroundColor(AppTheme.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .card()
    }

    private static func format(_ seconds: Double) -> String {
        if seconds >= 60 {
            let m = Int(seconds) / 60
            let s = Int(seconds) % 60
            return String(format: "%d:%02d", m, s)
        }
        return String(format: "%.1fs", seconds)
    }
}

/// Secondary row of token counts. Kept compact so it doesn't compete with
/// the timing grid above.
private struct TokenRow: View {
    let usage: TokenUsage

    var body: some View {
        HStack(spacing: 14) {
            Label("Claude tokens", systemImage: "number")
                .font(AppTheme.bodySmall)
                .foregroundColor(AppTheme.textSecondary)

            tokenPair(label: "in",     value: usage.inputTokens)
            tokenPair(label: "out",    value: usage.outputTokens)
            tokenPair(label: "billed", value: usage.billedTokens)

            if let read = usage.cacheReadInputTokens, read > 0 {
                tokenPair(label: "cache read", value: read)
            }
            if let write = usage.cacheCreationInputTokens, write > 0 {
                tokenPair(label: "cache write", value: write)
            }

            Spacer()
        }
    }

    private func tokenPair(label: String, value: Int) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(AppTheme.monoSmall)
                .foregroundColor(AppTheme.textTertiary)
            Text(Self.fmt.string(from: NSNumber(value: value)) ?? "\(value)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(AppTheme.text)
        }
    }

    private static let fmt: NumberFormatter = {
        // `.decimal` already supplies a locale-appropriate grouping separator
        // (e.g. "," in en-US, "." in de-DE, " " in fr-FR).
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()
}

private struct Metric: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(AppTheme.sectionLabel)
                .tracking(0.6)
                .foregroundColor(AppTheme.textTertiary)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(AppTheme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
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
        transcript: nil,
        metrics: PipelineMetrics(
            audioDurationSeconds: 2538,
            transcribeSeconds: 142.3,
            notesSeconds: 8.1,
            totalSeconds: 151.7,
            includedModelLoad: false,
            transcribeModel: WhisperKitTranscriber.modelVariant,
            notesModel: ClaudeNotesGenerator.modelID,
            tokenUsage: TokenUsage(
                inputTokens: 12_481,
                outputTokens: 624,
                cacheCreationInputTokens: nil,
                cacheReadInputTokens: nil
            )
        )
    )
    return NotesView(controller: c)
        .frame(width: 760, height: 720)
}
