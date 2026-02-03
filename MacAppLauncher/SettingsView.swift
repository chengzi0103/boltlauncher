import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appStore: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Launch at login", isOn: Binding(
                get: { appStore.loginEnabled },
                set: { appStore.toggleLogin($0) }
            ))

            Divider()

            HStack {
                Text("Apps")
                    .font(.headline)
                Spacer()
                Button("Add App...") {
                    appStore.addAppFromPanel()
                }
            }

            if appStore.apps.isEmpty {
                Text("Add apps and record hotkeys to get started.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appStore.apps) { app in
                    AppRow(app: app)
                }
            }
        }
        .padding(16)
        .frame(width: 520)
    }
}

private struct AppRow: View {
    @EnvironmentObject private var appStore: AppStore
    let app: AppEntry

    var body: some View {
        HStack {
            Text(app.name)
                .lineLimit(1)
            Spacer()
            HotkeyRecorder(hotkey: app.hotkey) { newHotkey in
                appStore.updateHotkey(for: app, hotkey: newHotkey)
            }
            Button("Remove") {
                appStore.remove(app: app)
            }
        }
    }
}
