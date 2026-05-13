import SwiftUI

struct DropdownView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero
            VStack(alignment: .leading, spacing: 6) {
                Text("Ready when you are.")
                    .font(AppTheme.headingFont(size: 20))
                    .foregroundColor(AppTheme.text)
                Text("⌘⇧R from anywhere")
                    .font(AppTheme.mono)
                    .foregroundColor(AppTheme.textTertiary)
            }
            .padding(AppTheme.padding)

            Divider().overlay(AppTheme.border)

            Button { controller.startRecording() } label: {
                HStack {
                    Circle().fill(AppTheme.recordingRed).frame(width: 8, height: 8)
                    Text("Start note-taking")
                        .font(AppTheme.body.weight(.medium))
                    Spacer()
                }
                .padding(.horizontal, AppTheme.padding)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .background(AppTheme.surface)
            .contentShape(Rectangle())

            Divider().overlay(AppTheme.border)

            RecentMeetingsList(
                meetings: controller.recentMeetings,
                onSelect: { controller.openMeeting($0) }
            )

            Divider().overlay(AppTheme.border)

            HStack {
                Spacer()
                SettingsLink {
                    Text("Settings")
                        .font(AppTheme.bodySmall)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .frame(width: AppTheme.dropdownWidth)
        .paperBackground()
    }
}

#Preview("Dropdown — with recents") {
    let c = AppController()
    c.recentMeetings = [
        MeetingRecord(id: "1", title: "Q2 Roadmap Review",
                      startedAt: .init(timeIntervalSinceNow: -3600), durationSeconds: 2538,
                      audioPath: "", transcriptPath: "", notesPath: ""),
        MeetingRecord(id: "2", title: "Design System Sync",
                      startedAt: .init(timeIntervalSinceNow: -86400), durationSeconds: 1140,
                      audioPath: "", transcriptPath: "", notesPath: "")
    ]
    return DropdownView(controller: c)
}

#Preview("Dropdown — empty") {
    DropdownView(controller: AppController())
}

private struct RecentMeetingsList: View {
    let meetings: [MeetingRecord]
    let onSelect: (MeetingRecord) -> Void

    var body: some View {
        if meetings.isEmpty {
            Text("No meetings yet")
                .font(AppTheme.bodySmall)
                .foregroundColor(AppTheme.textTertiary)
                .padding(AppTheme.padding)
        } else {
            VStack(spacing: 0) {
                HStack {
                    Text("Recent")
                        .font(AppTheme.monoSmall)
                        .foregroundColor(AppTheme.textTertiary)
                    Spacer()
                }
                .padding(.horizontal, AppTheme.padding)
                .padding(.top, 10).padding(.bottom, 4)

                ForEach(meetings) { m in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.title)
                                .font(AppTheme.body)
                                .foregroundColor(AppTheme.text)
                                .lineLimit(1)
                            Text("\(m.formattedDate) · \(m.formattedDuration)")
                                .font(AppTheme.monoSmall)
                                .foregroundColor(AppTheme.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, AppTheme.padding)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(m) }
                }
            }
        }
    }
}
