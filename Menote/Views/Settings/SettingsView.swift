import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    let controller: AppController
    @State private var apiKey = KeychainManager.shared.apiKey ?? ""
    @State private var saved = false

    var body: some View {
        Form {
            Section("Claude API") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key").font(AppTheme.body.weight(.medium))
                    SecureField("sk-ant-…", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(AppTheme.mono)
                    Text("Stored in macOS Keychain, never leaves your device.")
                        .font(AppTheme.bodySmall)
                        .foregroundColor(AppTheme.textSecondary)
                    HStack {
                        Button("Save") {
                            KeychainManager.shared.apiKey = apiKey
                            saved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(apiKey.isEmpty)

                        if saved {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .foregroundColor(AppTheme.doneGreen)
                                .font(AppTheme.bodySmall)
                        }
                    }
                }
            }
            Section("Keyboard Shortcut") {
                KeyboardShortcuts.Recorder("Toggle recording:", name: .toggleRecording)
            }
            Section("About") {
                HStack {
                    Text("Menote")
                    Spacer()
                    Text("v1.0").foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 340)
        .paperBackground()
    }
}

#Preview("Settings") {
    SettingsView(controller: AppController())
}
