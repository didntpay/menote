import SwiftUI

struct MainView: View {
    @ObservedObject var controller: AppController
    @State private var selectedTab: NotesTab = .notes

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(controller: controller)
                .frame(width: AppTheme.sidebarWidth)
                .background(AppTheme.sidebar.ignoresSafeArea())

            // The only visual separator between sidebar and detail now that both
            // backgrounds use AppTheme.background. Drop this Rectangle for a fully
            // unified canvas.
            Rectangle()
                .fill(AppTheme.border)
                .frame(width: 1)
                .padding(.top, AppTheme.titleBarReserve) // clean top edge under title bar
                .ignoresSafeArea()

            DetailPane(controller: controller, selectedTab: $selectedTab)
                .background(AppTheme.background.ignoresSafeArea())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background.ignoresSafeArea())
        .toolbarBackground(.hidden, for: .windowToolbar)
        .navigationTitle(controller.notes.selectedMeeting?.title ?? "Menote")
        .sheet(isPresented: Binding(
            get: { controller.appState == .permissionsRequired },
            set: { if !$0 { controller.resetToIdle() } }
        )) {
            PermissionsView(
                onGrant: { controller.resetToIdle() },
                onDismiss: { controller.resetToIdle() }
            )
        }
    }
}

// MARK: - Tabs

enum NotesTab: String, CaseIterable, Hashable {
    case notes, transcript

    var label: String {
        switch self {
        case .notes:      return "Notes"
        case .transcript: return "Transcript"
        }
    }

    var systemImage: String {
        switch self {
        case .notes:      return "doc.text"
        case .transcript: return "text.alignleft"
        }
    }
}

// MARK: - Sidebar

private struct SidebarView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        VStack(spacing: 0) {
            StartButton(controller: controller)
                .padding(.horizontal, 12)
                .padding(.top, AppTheme.titleBarReserve + 8)
                .padding(.bottom, 12)

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
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(controller.recentMeetings.grouped, id: \.group) { section in
                            GroupHeader(text: section.group.localizedName)
                                .padding(.horizontal, 16)
                                .padding(.top, 14)
                                .padding(.bottom, 4)

                            ForEach(section.items) { meeting in
                                MeetingRow(
                                    meeting: meeting,
                                    isSelected: controller.notes.selectedMeeting?.id == meeting.id
                                )
                                .onTapGesture { controller.openMeeting(meeting) }
                            }
                        }
                    }
                    .padding(.bottom, 12)
                }
            }

            Divider().overlay(AppTheme.border)

            // Settings link footer
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
        .background(AppTheme.sidebar.ignoresSafeArea())
        .scrollContentBackground(.hidden)
    }
}

private struct GroupHeader: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(AppTheme.groupHeader)
            .tracking(0.6)
            .foregroundColor(AppTheme.textTertiary)
    }
}

private struct MeetingRow: View {
    let meeting: MeetingRecord
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textTertiary)
                .frame(width: 16)

            Text(meeting.title)
                .font(AppTheme.body)
                .foregroundColor(AppTheme.text)
                .lineLimit(1)

            Spacer()

            Text(meeting.sidebarTimestamp)
                .font(AppTheme.monoSmall)
                .foregroundColor(AppTheme.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isSelected ? AppTheme.rowSelected : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
    }
}

// MARK: - Start button (idle / generating / error)

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
                            .font(AppTheme.bodyMedium)
                            .foregroundColor(AppTheme.text)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                            .strokeBorder(AppTheme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

            case .generating(let stage, let progress):
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7).frame(width: 12, height: 12)
                    Text("\(stage) · \(Int(progress * 100))%")
                        .font(AppTheme.monoSmall)
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                        .strokeBorder(AppTheme.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )

            case .error(let msg):
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(AppTheme.pauseYellow)
                            .font(.system(size: 11))
                            .padding(.top, 2)
                        Text(msg)
                            .font(AppTheme.bodySmall)
                            .foregroundColor(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    HStack(spacing: 8) {
                        if msg.contains("API key") {
                            SettingsLink {
                                Text("Open Settings")
                                    .font(AppTheme.bodySmall.weight(.medium))
                                    .foregroundColor(AppTheme.actionBlue)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                        Button("Dismiss") { controller.resetToIdle() }
                            .buttonStyle(.plain)
                            .font(AppTheme.bodySmall)
                            .foregroundColor(AppTheme.textTertiary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                        .strokeBorder(AppTheme.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )

            default:
                EmptyView()
            }
        }
    }
}

// MARK: - Detail pane

private struct DetailPane: View {
    @ObservedObject var controller: AppController
    @Binding var selectedTab: NotesTab

    var body: some View {
        VStack(spacing: 0) {
            if controller.notes.selectedMeeting != nil {
                TabBar(selection: $selectedTab)
                    .padding(.top, AppTheme.titleBarReserve)
                Divider().overlay(AppTheme.border)
            } else {
                Color.clear.frame(height: AppTheme.titleBarReserve)
            }

            Group {
                if controller.notes.selectedMeeting != nil {
                    switch selectedTab {
                    case .notes:      NotesView(controller: controller.notes)
                    case .transcript: TranscriptView(controller: controller.notes)
                    }
                } else {
                    EmptyDetailView()
                }
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
    }
}

private struct TabBar: View {
    @Binding var selection: NotesTab

    var body: some View {
        HStack(spacing: 4) {
            Spacer()
            ForEach(NotesTab.allCases, id: \.self) { tab in
                TabButton(tab: tab, isSelected: tab == selection) {
                    selection = tab
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppTheme.background)
    }
}

private struct TabButton: View {
    let tab: NotesTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 12, weight: .medium))
                Text(tab.label)
                    .font(AppTheme.bodyMedium)
            }
            .foregroundColor(isSelected ? AppTheme.text : AppTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? AppTheme.card : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isSelected ? AppTheme.border : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty state

private struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Menote")
                .font(AppTheme.titleFont(size: 28))
                .foregroundColor(AppTheme.textTertiary)
            Text("Start a recording or select a past meeting.")
                .font(AppTheme.body)
                .foregroundColor(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}

// MARK: - Preview

#Preview("Main — empty") {
    MainView(controller: AppController())
        .frame(width: 900, height: 600)
}

#Preview("Main — with meetings") {
    let c = AppController()
    c.recentMeetings = [
        MeetingRecord(id: "1", title: "Roadmap review · Q2",
                      startedAt: .init(timeIntervalSinceNow: -3600), durationSeconds: 2538,
                      audioPath: "", transcriptPath: "", notesPath: ""),
        MeetingRecord(id: "2", title: "Sales pipeline",
                      startedAt: .init(timeIntervalSinceNow: -7200), durationSeconds: 1140,
                      audioPath: "", transcriptPath: "", notesPath: ""),
        MeetingRecord(id: "3", title: "1:1 with Maya",
                      startedAt: .init(timeIntervalSinceNow: -86400 * 2), durationSeconds: 1800,
                      audioPath: "", transcriptPath: "", notesPath: "")
    ]
    return MainView(controller: c)
        .frame(width: 900, height: 600)
}
