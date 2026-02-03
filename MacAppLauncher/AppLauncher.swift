import AppKit
import Foundation

final class AppLauncher {
    func toggle(app: AppEntry, completion: @escaping (LaunchResult) -> Void) {
        if isFrontmost(bundleId: app.bundleId) {
            if let running = runningApp(bundleId: app.bundleId) {
                let hidden = running.hide()
                completion(hidden ? .hidden : .failed)
            } else {
                completion(.failed)
            }
            return
        }
        activate(app: app, completion: completion)
    }

    private func activate(app: AppEntry, completion: @escaping (LaunchResult) -> Void) {
        if let running = runningApp(bundleId: app.bundleId) {
            let activated = running.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            completion(activated ? .launched : .failed)
            return
        }

        let url = URL(fileURLWithPath: app.path)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { appInstance, _ in
            if let appInstance {
                let activated = appInstance.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                completion(activated ? .launched : .failed)
            } else {
                completion(.failed)
            }
        }
    }

    private func isFrontmost(bundleId: String) -> Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleId
    }

    private func runningApp(bundleId: String) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first
    }
}
