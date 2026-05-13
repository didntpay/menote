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
        .windowToolbarStyle(.unified)
        .defaultSize(width: 860, height: 560)
        .commands {
            CommandGroup(replacing: .newItem) {}   // hide File > New
        }

        Settings {
            SettingsView(controller: delegate.appController)
        }
    }
}
