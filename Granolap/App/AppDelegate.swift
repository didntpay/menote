import AppKit
import KeyboardShortcuts

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    let appController = AppController()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationManager.shared.requestAuthorization()
        statusBarController = StatusBarController(controller: appController)

        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            self?.appController.handleShortcut()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
