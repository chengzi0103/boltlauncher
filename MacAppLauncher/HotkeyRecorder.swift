import AppKit
import SwiftUI

struct HotkeyRecorder: View {
    let hotkey: Hotkey
    let onUpdate: (Hotkey) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(isRecording ? "Recording..." : hotkey.displayString) {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let newHotkey = Hotkey(keyCode: Int(event.keyCode), modifiers: Int(modifiers.rawValue))
            onUpdate(newHotkey)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
