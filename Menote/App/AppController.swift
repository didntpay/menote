import Foundation
import SwiftUI
import Combine
import AVFoundation

// Top-level coordinator. Owns sub-controllers and drives the generation pipeline.
@MainActor
final class AppController: ObservableObject {

    enum AppState: Equatable {
        case idle
        case permissionsRequired
        case generating(stage: String, progress: Double)
        case error(String)

        static func == (lhs: AppState, rhs: AppState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.permissionsRequired, .permissionsRequired): return true
            case (.generating(let a, let b), .generating(let c, let d)): return a == c && b == d
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    @Published var appState: AppState = .idle
    @Published var recentMeetings: [MeetingRecord] = []
    @Published var notesJustReady = false

    // Sub-controllers exposed so views can read/observe them directly.
    let recorder: RecorderController
    let notes: NotesController

    private let store: MeetingStore
    private var cancellables = Set<AnyCancellable>()
    private var notesReadyResetTask: Task<Void, Never>?

    init() {
        let store = MeetingStore()
        self.store = store
        self.recorder = RecorderController(store: store)
        self.notes = NotesController(store: store)
        self.recentMeetings = store.fetchRecent()

        // Forward only the controller-level changes (state transitions) so views
        // observing AppController re-render on those. High-frequency meter updates
        // are NOT forwarded — views that need them observe the managers directly.
        recorder.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        notes.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Recording actions (called by views / shortcuts)

    var hasAPIKey: Bool {
        !(KeychainManager.shared.apiKey ?? "").isEmpty
    }

    /// Returns the app from `.error` or `.permissionsRequired` back to `.idle`.
    func resetToIdle() {
        switch appState {
        case .error, .permissionsRequired: appState = .idle
        default: break
        }
    }

    func startRecording() {
        guard hasAPIKey else {
            appState = .error("No Anthropic API key — add one in Settings.")
            return
        }
        guard recorder.hasMicPermission() else {
            if AVAuthorizationStatus.notDetermined == AVCaptureDevice.authorizationStatus(for: .audio) {
                recorder.requestMicPermission { granted in
                    DispatchQueue.main.async {
                        if granted { self.startRecording() }
                        else { self.appState = .error("Microphone access denied.") }
                    }
                }
            } else {
                appState = .permissionsRequired
            }
            return
        }
        do {
            try recorder.start()
        } catch {
            appState = .error(error.localizedDescription)
        }
    }

    func pauseRecording()  { recorder.pause() }
    func resumeRecording() { recorder.resume() }

    func endRecording() {
        appState = .generating(stage: "mixing audio", progress: 0.02)
        Task {
            guard let session = await recorder.end() else {
                appState = .error("No active recording session.")
                return
            }
            appState = .generating(stage: "transcribing", progress: 0.05)
            await runGenerationPipeline(session: session)
        }
    }

    func handleShortcut() {
        if case .idle = appState, !recorder.state.isActive {
            startRecording()
        }
    }

    func openMeeting(_ meeting: MeetingRecord) {
        notes.open(meeting)
    }

    // MARK: - Pipeline

    private func runGenerationPipeline(session: RecorderController.Session) async {
        do {
            // Transcribe
            appState = .generating(stage: "transcribing", progress: 0.1)
            let transcriber = WhisperKitTranscriber()
            let transcript = try await transcriber.transcribe(audioURL: session.audioURL)

            // Generate notes
            appState = .generating(stage: "writing notes", progress: 0.5)
            let apiKey = KeychainManager.shared.apiKey ?? ""
            let generator = ClaudeNotesGenerator(apiKey: apiKey)
            let notesData = try await generator.generateNotes(from: transcript)

            // Persist
            appState = .generating(stage: "finishing up", progress: 0.9)
            let record = try store.save(
                id: session.id,
                sessionDir: session.dir,
                audioURL: session.audioURL,
                transcript: transcript,
                notes: notesData,
                durationSeconds: session.durationSeconds,
                startedAt: session.startedAt
            )

            recentMeetings = store.fetchRecent()
            notes.open(record)
            appState = .idle
            flashNotesReady()

            NotificationManager.shared.postNotesReady(
                title: notesData.title,
                actionCount: notesData.actionItems.filter { !$0.done }.count
            )

        } catch {
            appState = .error(error.localizedDescription)
        }
    }

    /// Sets `notesJustReady = true` for 3 seconds. Cancels any prior pending reset
    /// so back-to-back recordings don't have the second reset clobbered by the first.
    private func flashNotesReady() {
        notesJustReady = true
        notesReadyResetTask?.cancel()
        notesReadyResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                self.notesJustReady = false
            }
        }
    }
}
