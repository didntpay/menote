import SwiftUI
import AVFoundation

struct PermissionsView: View {
    let onGrant: () -> Void
    let onDismiss: () -> Void

    @State private var micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Before we start")
                .font(AppTheme.headingFont(size: 22))

            Text("Granolap needs two permissions to capture your meeting.")
                .font(AppTheme.body)
                .foregroundColor(AppTheme.textSecondary)

            PermissionRow(icon: "mic.fill", title: "Microphone",
                          description: "To record your voice.", isGranted: micGranted) {
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    DispatchQueue.main.async { micGranted = granted }
                }
            }

            PermissionRow(icon: "desktopcomputer", title: "Screen & system audio",
                          description: "To capture audio from other apps.", isGranted: false) {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                )
            }

            Spacer()

            HStack {
                Button("Not now", action: onDismiss).buttonStyle(.plain)
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Button("Continue →", action: onGrant).buttonStyle(.plain)
                    .foregroundColor(AppTheme.actionBlue)
                    .disabled(!micGranted)
            }
        }
        .padding(AppTheme.padding)
        .frame(width: 340, height: 300)
        .paperBackground()
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
    let onGrant: () -> Void

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
                Button("Grant", action: onGrant).buttonStyle(.plain)
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
