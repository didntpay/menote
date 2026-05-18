import AppKit
import SwiftUI
import KeyboardShortcuts

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    let appController = AppController()
    private var statusBarController: StatusBarController?
    private var windowObserver: NSObjectProtocol?
    private var hasConfiguredMainWindow = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationManager.shared.requestAuthorization()
        statusBarController = StatusBarController(controller: appController)

        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            self?.appController.handleShortcut()
        }

        // Style the main window once it's created — transparent title bar so the
        // sidebar/detail backgrounds extend under the titlebar zone seamlessly.
        // `didBecomeMainNotification` fires every focus change; we only need the
        // first one for our window, so gate with hasConfiguredMainWindow.
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  !self.hasConfiguredMainWindow,
                  let window = notification.object as? NSWindow,
                  window.identifier?.rawValue == "main" else { return }
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.backgroundColor = NSColor(AppTheme.background)
            self.hasConfiguredMainWindow = true
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
