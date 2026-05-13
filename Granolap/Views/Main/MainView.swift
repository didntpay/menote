import SwiftUI

struct MainView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        NavigationSplitView {
            SidebarView(controller: controller)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            DetailPane(controller: controller)
        }
        .background(AppTheme.background)
    }
}

// MARK: - Sidebar

private struct SidebarView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        VStack(spacing: 0) {

            // Start button
            StartButton(controller: controller)
                .padding(12)

            Divider().overlay(AppTheme.border)

            // Meetings list
            if controller.recentMeetings.isEmpty {
                Spacer()
                Text("No meetings yet.\nStart your first recording.")
                    .font(AppTheme.bodySmall)
                    .foregroundColor(AppTheme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(AppTheme.padding)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(controller.recentMeetings) { meeting in
                            MeetingRow(
                                meeting: meeting,
                                isSelected: controller.notes.selectedMeeting?.id == meeting.id
                            )
                            .onTapGesture { controller.openMeeting(meeting) }

                            Divider()
                                .overlay(AppTheme.border.opacity(0.5))
                                .padding(.leading, 12)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            Divider().overlay(AppTheme.border)

            // Settings link
            HStack {
                Spacer()
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                        .font(AppTheme.bodySmall)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.vertical, 10)
        }
        .paperBackground()
    }
}

private struct StartButton: View {
    @ObservedObject var controller: AppController

    var body: some View {
        Group {
            switch controller.appState {
            case .idle:
                Button {
                    controller.startRecording()
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(AppTheme.recordingRed)
                            .frame(width: 9, height: 9)
                        Text("Start note-taking")
                            .font(AppTheme.body.weight(.medium))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.surface)
                    .cornerRadius(AppTheme.cornerRadius)
                    .paperBorder()
                }
                .buttonStyle(.plain)

            case .generating(let stage, let progress):
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7).frame(width: 12, height: 12)
                    Text("\(stage) · \(Int(progress * 100))%")
                        .font(AppTheme.monoSmall)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.surface)
                .cornerRadius(AppTheme.cornerRadius)
                .paperBorder(dashed: true)

            case .error(let msg):
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(AppTheme.pauseYellow)
                        .font(.system(size: 11))
                    Text(msg)
                        .font(AppTheme.monoSmall)
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.surface)
                .cornerRadius(AppTheme.cornerRadius)
                .paperBorder(dashed: true)

            default:
                EmptyView()
            }
        }
    }
}

private struct MeetingRow: View {
    let meeting: MeetingRecord
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(meeting.title)
                    .font(AppTheme.body)
                    .foregroundColor(AppTheme.text)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(meeting.formattedDate)
                    Text("·")
                    Text(meeting.formattedDuration)
                }
                .font(AppTheme.monoSmall)
                .foregroundColor(AppTheme.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(isSelected ? AppTheme.surface : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Detail pane

private struct DetailPane: View {
    @ObservedObject var controller: AppController

    var body: some View {
        if controller.notes.selectedMeeting != nil {
            NotesView(controller: controller.notes)
        } else {
            EmptyDetailView()
        }
    }
}

private struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Menote")
                .font(AppTheme.headingFont(size: 28))
                .foregroundColor(AppTheme.textTertiary)
            Text("Start a recording or select a past meeting.")
                .font(AppTheme.body)
                .foregroundColor(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paperBackground()
    }
}

// MARK: - Preview

#Preview("Main — empty") {
    MainView(controller: AppController())
        .frame(width: 820, height: 560)
}

#Preview("Main — with meetings") {
    let c = AppController()
    c.recentMeetings = [
        MeetingRecord(id: "1", title: "Q2 Roadmap Review",
                      startedAt: .init(timeIntervalSinceNow: -3600), durationSeconds: 2538,
                      audioPath: "", transcriptPath: "", notesPath: ""),
        MeetingRecord(id: "2", title: "Design System Sync",
                      startedAt: .init(timeIntervalSinceNow: -86400), durationSeconds: 1140,
                      audioPath: "", transcriptPath: "", notesPath: "")
    ]
    return MainView(controller: c)
        .frame(width: 820, height: 560)
}
