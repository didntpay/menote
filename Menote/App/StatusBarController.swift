import AppKit
import SwiftUI
import Combine

@MainActor
final class StatusBarController {

    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var recorderWindowController: NSWindowController?
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    private let controller: AppController

    init(controller: AppController) {
        self.controller = controller

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        popover = NSPopover()
        popover.contentSize = NSSize(width: AppTheme.dropdownWidth, height: 360)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: DropdownView(controller: controller)
        )

        if let btn = statusItem.button {
            btn.title = "○"
            btn.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
            btn.action = #selector(handleClick)
            btn.target = self
        }

        // Observe AppState
        controller.$appState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in self?.updateButton(appState: state) }
            .store(in: &cancellables)

        // Observe recorder state
        controller.recorder.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in self?.updateButton(recorderState: state) }
            .store(in: &cancellables)

        // Focus main window when notes become ready
        controller.notes.$selectedMeeting
            .dropFirst()
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { _ in StatusBarController.focusMainWindow() }
            .store(in: &cancellables)
    }

    // MARK: - Button label

    private func updateButton(appState: AppController.AppState? = nil, recorderState: RecorderController.State? = nil) {
        guard let btn = statusItem.button else { return }

        // Recorder state takes precedence when active
        if let rs = recorderState ?? Optional(controller.recorder.state), rs.isActive {
            let prefix = (recorderState == nil ? false : { if case .paused = controller.recorder.state { return true }; return false }())
                ? "⏸" : "●"
            btn.title = "\(prefix) \(controller.recorder.state.elapsed.formattedElapsed)"
            showRecorderWindow()
            return
        }

        let state = appState ?? controller.appState
        switch state {
        case .idle:
            btn.title = "○"
            closeRecorderWindow()
        case .permissionsRequired:
            btn.title = "○"
        case .generating(let stage, let progress):
            btn.title = "◌ \(stage) · \(Int(progress * 100))%"
        case .error:
            btn.title = "⚠"
            closeRecorderWindow()
        }
    }

    // MARK: - Popover

    @objc private func handleClick() {
        if controller.recorder.state.isActive {
            showRecorderWindow()
        } else {
            StatusBarController.focusMainWindow()
        }
    }

    static func focusMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let w = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            w.makeKeyAndOrderFront(nil)
        } else {
            // SwiftUI WindowGroup hasn't opened yet — open via AppDelegate menu trick
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            removeEventMonitor()
        } else {
            guard let btn = statusItem.button else { return }
            popover.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            installEventMonitor()
        }
    }

    private func installEventMonitor() {
        removeEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.popover.performClose(nil)
            self?.removeEventMonitor()
        }
    }

    private func removeEventMonitor() {
        if let m = eventMonitor { NSEvent.removeMonitor(m) }
        eventMonitor = nil
    }

    // MARK: - Recorder window

    private func showRecorderWindow() {
        if recorderWindowController == nil {
            recorderWindowController = makeRecorderWindow()
        }
        recorderWindowController?.showWindow(nil)
        recorderWindowController?.window?.makeKeyAndOrderFront(nil)
        if popover.isShown { popover.performClose(nil) }
    }

    private func closeRecorderWindow() {
        recorderWindowController?.window?.orderOut(nil)
        recorderWindowController = nil
    }

    private func makeRecorderWindow() -> NSWindowController {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: AppTheme.recorderWidth, height: AppTheme.recorderHeight),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.titlebarAppearsTransparent = true
        panel.title = ""
        panel.isMovableByWindowBackground = true
        panel.center()
        panel.contentViewController = NSHostingController(
            rootView: RecorderView(controller: controller)
        )
        return NSWindowController(window: panel)
    }

}

extension TimeInterval {
    var formattedElapsed: String {
        let total = Int(self)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}
