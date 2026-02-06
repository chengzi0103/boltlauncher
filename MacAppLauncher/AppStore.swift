import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppStore: ObservableObject {
    @Published var apps: [AppEntry] = []
    @Published var loginEnabled: Bool
    @Published var screenshotHotkey: Hotkey
    @Published var screenshotEnabled: Bool

    private let store: SQLiteStore
    private let launcher: AppLauncher
    private let loginItemManager: LoginItemManager
    private let screenshotManager: ScreenshotManager
    private lazy var hotkeyManager: HotkeyManager = {
        HotkeyManager { [weak self] action in
            self?.handleHotkey(action)
        }
    }()

    init() {
        store = SQLiteStore()
        launcher = AppLauncher()
        loginItemManager = LoginItemManager()
        screenshotManager = ScreenshotManager()
        loginEnabled = loginItemManager.isEnabled
        screenshotHotkey = store.fetchScreenshotHotkey()
        screenshotEnabled = store.fetchScreenshotEnabled()
        reload()
    }

    func reload() {
        apps = store.fetchApps()
        screenshotHotkey = store.fetchScreenshotHotkey()
        screenshotEnabled = store.fetchScreenshotEnabled()
        hotkeyManager.register(
            apps: apps,
            screenshotHotkey: screenshotEnabled ? screenshotHotkey : nil
        )
    }

    func addAppFromPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            guard let bundle = Bundle(url: url) else { return }
            let bundleId = bundle.bundleIdentifier ?? url.lastPathComponent
            let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? url.deletingPathExtension().lastPathComponent
            store.upsertApp(bundleId: bundleId, name: name, path: url.path)
            reload()
        }
    }

    func updateHotkey(for app: AppEntry, hotkey: Hotkey) {
        store.updateHotkey(appId: app.id, hotkey: hotkey)
        reload()
    }

    func remove(app: AppEntry) {
        store.removeApp(appId: app.id)
        reload()
    }

    func launch(app: AppEntry) {
        launcher.toggle(app: app) { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                if result == .launched {
                    self.store.logLaunch(appId: app.id, at: Date())
                    self.reload()
                }
            }
        }
    }

    func toggleLogin(_ enabled: Bool) {
        loginItemManager.setEnabled(enabled)
        loginEnabled = loginItemManager.isEnabled
    }

    func updateScreenshotHotkey(_ hotkey: Hotkey) {
        store.updateScreenshotHotkey(hotkey)
        reload()
    }

    func updateScreenshotEnabled(_ enabled: Bool) {
        store.updateScreenshotEnabled(enabled)
        reload()
    }

    private func handleHotkey(_ action: HotkeyAction) {
        switch action {
        case .app(let appId):
            guard let app = apps.first(where: { $0.id == appId }) else { return }
            launch(app: app)
        case .screenshot:
            guard screenshotEnabled else { return }
            screenshotManager.startCapture()
        }
    }
}
