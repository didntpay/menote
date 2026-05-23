import Foundation
import SwiftUI
import Combine
import AVFoundation
import AppKit
import UniformTypeIdentifiers

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
    let transcriber = WhisperKitTranscriber()

    private let store: MeetingStore
    private var cancellables = Set<AnyCancellable>()
    private var notesReadyResetTask: Task<Void, Never>?
    private var lastPublishedProgress: Double = -1

    init() {
        let store = MeetingStore()
        self.store = store
        self.recorder = RecorderController(store: store)
        self.notes = NotesController(store: store)
        self.recentMeetings = store.fetchRecent(limit: 100)

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

    /// Side-effecting precondition check: returns `false` and parks `appState`
    /// in `.error` when the user has no API key configured. Use at the top of
    /// any flow that will eventually hit Claude.
    private func requireAPIKey() -> Bool {
        guard hasAPIKey else {
            appState = .error("No Anthropic API key — add one in Settings.")
            return false
        }
        return true
    }

    func startRecording() {
        guard requireAPIKey() else { return }
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
        guard let session = recorder.end() else {
            appState = .error("No active recording session.")
            return
        }
        Task { await runGenerationPipeline(session: session, imported: false) }
    }

    /// Opens a file picker, copies the chosen audio into a fresh session
    /// directory, then runs the same transcribe → notes pipeline used for
    /// live recordings. Lets us benchmark the current pipeline on real
    /// audio before optimizing for long sessions.
    func importAudioFile() {
        guard requireAPIKey() else { return }
        guard case .idle = appState, !recorder.state.isActive else { return }

        let panel = NSOpenPanel()
        panel.title = "Import audio for transcription"
        panel.message = "Pick a recording to run through the transcribe → notes pipeline."
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = Self.importableAudioTypes
        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task { await runImportPipeline(sourceURL: url) }
    }

    // `.audio` is the umbrella UTType; NSOpenPanel accepts every conforming
    // format (mp3, m4a, wav, aiff, caf, …) so we don't need to enumerate them.
    private static let importableAudioTypes: [UTType] = [.audio]

    private func runImportPipeline(sourceURL: URL) async {
        do {
            let (id, sessionDir) = try store.newSessionDirectory()
            let rawExt = sourceURL.pathExtension
            let ext = (rawExt.isEmpty ? "m4a" : rawExt).lowercased()
            let dest = sessionDir.appendingPathComponent("audio.\(ext)")
            try FileManager.default.copyItem(at: sourceURL, to: dest)

            let seconds = (try? await Self.audioDuration(at: dest)) ?? 0
            let durationSeconds = Int(seconds.rounded())

            let session = RecorderController.Session(
                id: id,
                dir: sessionDir,
                audioURL: dest,
                durationSeconds: durationSeconds,
                startedAt: Date()
            )
            await runGenerationPipeline(session: session, imported: true)
        } catch {
            appState = .error("Import failed: \(error.localizedDescription)")
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

    private func runGenerationPipeline(
        session: RecorderController.Session,
        imported: Bool
    ) async {
        let pipelineStart = Date()
        // Tracks whether the transcribe step paid the one-time model download/load cost.
        // Read inside the progress callback (any stage other than "transcribing" means
        // model work happened first); captured into the metrics record at the end.
        var sawModelLoad = false
        do {
            // Transcribe — WhisperKit downloads the model on first run.
            appState = .generating(stage: "preparing model", progress: 0.05)
            lastPublishedProgress = 0.05
            transcriber.onProgress = { [weak self] stage, p in
                guard let self else { return }
                if stage != "transcribing" { sawModelLoad = true }
                // Map transcriber sub-progress into the 0.05 → 0.50 band of the pipeline.
                // Throttle: only publish when stage changes or progress moves by >= 1%.
                let mapped = 0.05 + p * 0.45
                if case .generating(let curStage, _) = self.appState,
                   curStage == stage,
                   abs(mapped - self.lastPublishedProgress) < 0.01 {
                    return
                }
                self.lastPublishedProgress = mapped
                self.appState = .generating(stage: stage, progress: mapped)
            }
            let transcribeStart = Date()
            let transcript = try await transcriber.transcribe(audioURL: session.audioURL)
            let transcribeSeconds = Date().timeIntervalSince(transcribeStart)

            // Generate notes
            appState = .generating(stage: "writing notes", progress: 0.5)
            let apiKey = KeychainManager.shared.apiKey ?? ""
            let generator = ClaudeNotesGenerator(apiKey: apiKey)
            let notesStart = Date()
            let generated = try await generator.generateNotes(from: transcript)
            let notesSeconds = Date().timeIntervalSince(notesStart)
            let notesData = generated.notes

            // Persist
            appState = .generating(stage: "finishing up", progress: 0.9)

            // True audio duration from the file — survives clock-drift in the live
            // timer, and is the only source for imported audio.
            let audioDuration = (try? await Self.audioDuration(at: session.audioURL))
                ?? Double(session.durationSeconds)

            let metrics = PipelineMetrics(
                audioDurationSeconds: audioDuration,
                transcribeSeconds: transcribeSeconds,
                notesSeconds: notesSeconds,
                totalSeconds: Date().timeIntervalSince(pipelineStart),
                includedModelLoad: sawModelLoad,
                transcribeModel: WhisperKitTranscriber.modelVariant,
                notesModel: ClaudeNotesGenerator.modelID,
                tokenUsage: generated.usage
            )

            let durationToStore = imported
                ? Int(audioDuration.rounded())
                : session.durationSeconds

            let record = try store.save(
                id: session.id,
                sessionDir: session.dir,
                audioURL: session.audioURL,
                transcript: transcript,
                notes: notesData,
                metrics: metrics,
                durationSeconds: durationToStore,
                startedAt: session.startedAt,
                imported: imported
            )

            recentMeetings = store.fetchRecent(limit: 100)
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

    private static func audioDuration(at url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)
        let cm = try await asset.load(.duration)
        let s = CMTimeGetSeconds(cm)
        return s.isFinite ? s : 0
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
