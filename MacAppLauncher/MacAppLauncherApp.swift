import SwiftUI

@main
struct MacAppLauncherApp: App {
    @StateObject private var appStore = AppStore()

    var body: some Scene {
        MenuBarExtra("BoltLauncher", systemImage: "bolt.circle") {
            MenuBarView()
                .environmentObject(appStore)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(appStore)
        }
    }
}
