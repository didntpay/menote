import Foundation
import AVFoundation

// Owns the recording session lifecycle. Knows nothing about UI.
@MainActor
final class RecorderController: ObservableObject {

    enum State {
        case idle
        case recording(elapsed: TimeInterval)
        case paused(elapsed: TimeInterval)
    }

    @Published private(set) var state: State = .idle

    let audio = AudioCaptureManager()

    private(set) var sessionID: String?
    private(set) var sessionDir: URL?
    private(set) var startedAt = Date()
    private(set) var elapsedSeconds: TimeInterval = 0

    private var elapsedTimer: Timer?
    private let store: MeetingStore

    init(store: MeetingStore) {
        self.store = store
    }

    // MARK: - Actions

    func start() throws {
        let (id, dir) = try store.newSessionDirectory()
        sessionID = id
        sessionDir = dir
        startedAt = Date()
        elapsedSeconds = 0

        try audio.startCapture(sessionDir: dir)
        state = .recording(elapsed: 0)
        startTimer()
    }

    func pause() {
        guard case .recording(let elapsed) = state else { return }
        audio.pause()
        elapsedTimer?.invalidate()
        state = .paused(elapsed: elapsed)
    }

    func resume() {
        guard case .paused(let elapsed) = state else { return }
        audio.resume()
        elapsedSeconds = elapsed
        state = .recording(elapsed: elapsed)
        startTimer()
    }

    /// Stops recording and returns session info.
    func end() -> Session? {
        elapsedTimer?.invalidate()
        guard let audioURL = audio.stop(),
              let id = sessionID,
              let dir = sessionDir else { return nil }

        let session = Session(
            id: id,
            dir: dir,
            audioURL: audioURL,
            durationSeconds: Int(elapsedSeconds),
            startedAt: startedAt
        )
        sessionID = nil
        sessionDir = nil
        state = .idle
        return session
    }

    // MARK: - Permissions

    func hasMicPermission() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func requestMicPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
    }

    // MARK: - Private

    private func startTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.elapsedSeconds += 1
            self.state = .recording(elapsed: self.elapsedSeconds)
        }
    }

    // MARK: - Session value type

    struct Session {
        let id: String
        let dir: URL
        let audioURL: URL
        let durationSeconds: Int
        let startedAt: Date
    }
}

extension RecorderController.State {
    var elapsed: TimeInterval {
        switch self {
        case .idle:              return 0
        case .recording(let e): return e
        case .paused(let e):    return e
        }
    }
    var isActive: Bool {
        if case .idle = self { return false }
        return true
    }
}
