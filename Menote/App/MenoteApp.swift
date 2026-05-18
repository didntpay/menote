import SwiftUI

@main
struct MenoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup("Menote", id: "main") {
            MainView(controller: delegate.appController)
                .frame(minWidth: 700, minHeight: 480)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: true))
        .defaultSize(width: 900, height: 620)
        .commands {
            CommandGroup(replacing: .newItem) {}   // hide File > New
        }

        Settings {
            SettingsView(controller: delegate.appController)
        }
    }
}
