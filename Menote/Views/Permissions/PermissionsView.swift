import SwiftUI
import AVFoundation
import AppKit

struct PermissionsView: View {
    let onGrant: () -> Void
    let onDismiss: () -> Void

    @State private var micStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Before we start")
                .font(AppTheme.headingFont(size: 22))

            Text("Menote needs microphone access to record your meeting.")
                .font(AppTheme.body)
                .foregroundColor(AppTheme.textSecondary)

            PermissionRow(
                icon: "mic.fill",
                title: "Microphone",
                description: "To record your voice.",
                isGranted: micStatus == .authorized,
                buttonTitle: micStatus == .notDetermined ? "Grant" : "Open Settings",
                onTap: handleMicTap
            )

            Spacer()

            HStack {
                Button("Not now", action: onDismiss).buttonStyle(.plain)
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Button("Continue →", action: onGrant).buttonStyle(.plain)
                    .foregroundColor(AppTheme.actionBlue)
                    .disabled(micStatus != .authorized)
            }
        }
        .padding(AppTheme.padding)
        .frame(width: 340, height: 220)
        .paperBackground()
        // When the user comes back from System Settings, re-check the status.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshStatus()
        }
    }

    private func handleMicTap() {
        switch micStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                DispatchQueue.main.async { refreshStatus() }
            }
        case .denied, .restricted:
            openSystemMicrophoneSettings()
        case .authorized:
            break
        @unknown default:
            openSystemMicrophoneSettings()
        }
    }

    private func refreshStatus() {
        micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    }

    private func openSystemMicrophoneSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else { return }
        NSWorkspace.shared.open(url)
    }
}

#Preview("Permissions") {
    PermissionsView(onGrant: {}, onDismiss: {})
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let buttonTitle: String
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .foregroundColor(isGranted ? AppTheme.doneGreen : AppTheme.textSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppTheme.body.weight(.medium))
                Text(description).font(AppTheme.bodySmall).foregroundColor(AppTheme.textSecondary)
            }
            Spacer()
            if isGranted {
                Image(systemName: "checkmark.circle.fill").foregroundColor(AppTheme.doneGreen)
            } else {
                Button(buttonTitle, action: onTap).buttonStyle(.plain)
                    .font(AppTheme.bodySmall.weight(.medium))
                    .foregroundColor(AppTheme.actionBlue)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(AppTheme.surface)
                    .cornerRadius(AppTheme.cornerRadius)
                    .paperBorder()
            }
        }
        .padding(AppTheme.paddingSmall)
        .background(AppTheme.surface)
        .cornerRadius(AppTheme.cornerRadius)
        .paperBorder()
    }
}
