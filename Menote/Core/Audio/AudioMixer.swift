import AVFoundation

enum AudioMixer {

    enum MixError: LocalizedError {
        case noMicTrack
        case exportSessionUnavailable
        case exportFailed(status: AVAssetExportSession.Status)

        var errorDescription: String? {
            switch self {
            case .noMicTrack:                return "Mic recording had no audio track."
            case .exportSessionUnavailable:  return "Could not create audio export session."
            case .exportFailed(let s):       return "Audio export failed (status \(s.rawValue))."
            }
        }
    }

    /// Mixes `mic` and `system` (if present) into a single AAC `.m4a` at `outputURL`.
    /// Throws on any failure. If `system` is nil or missing on disk, returns `mic` unchanged.
    static func mix(mic: URL, system: URL?, outputURL: URL) async throws -> URL {
        guard let system, FileManager.default.fileExists(atPath: system.path) else {
            return mic
        }

        try? FileManager.default.removeItem(at: outputURL)

        let composition = AVMutableComposition()
        let micAsset = AVURLAsset(url: mic)
        let sysAsset = AVURLAsset(url: system)

        let micTracks = try await micAsset.loadTracks(withMediaType: .audio)
        let sysTracks = try await sysAsset.loadTracks(withMediaType: .audio)

        guard let micTrack = micTracks.first else { throw MixError.noMicTrack }

        let micDuration = try await micAsset.load(.duration)
        let micComp = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        try micComp?.insertTimeRange(CMTimeRange(start: .zero, duration: micDuration), of: micTrack, at: .zero)

        if let sysTrack = sysTracks.first {
            let sysDuration = try await sysAsset.load(.duration)
            let sysComp = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            try sysComp?.insertTimeRange(CMTimeRange(start: .zero, duration: sysDuration), of: sysTrack, at: .zero)
        }

        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw MixError.exportSessionUnavailable
        }
        export.outputURL = outputURL
        export.outputFileType = .m4a

        await export.export()
        guard export.status == .completed else {
            if let e = export.error { throw e }
            throw MixError.exportFailed(status: export.status)
        }
        return outputURL
    }
}
