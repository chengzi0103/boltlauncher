import AppKit
import Carbon
import Foundation

final class HotkeyManager {
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var hotKeyIdToAction: [UInt32: HotkeyAction] = [:]
    private var nextId: UInt32 = 1
    private var handlerInstalled = false
    private let onTrigger: (HotkeyAction) -> Void

    init(onTrigger: @escaping (HotkeyAction) -> Void) {
        self.onTrigger = onTrigger
        installHandlerIfNeeded()
    }

    func register(apps: [AppEntry], screenshotHotkey: Hotkey?) {
        unregisterAll()
        for app in apps {
            if app.hotkey.keyCode < 0 {
                continue
            }
            registerHotkey(keyCode: app.hotkey.keyCode, modifiers: app.hotkey.modifierFlags, action: .app(app.id))
        }
        if let screenshotHotkey, screenshotHotkey.keyCode >= 0 {
            registerHotkey(keyCode: screenshotHotkey.keyCode, modifiers: screenshotHotkey.modifierFlags, action: .screenshot)
        }
    }

    func unregisterAll() {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        hotKeyIdToAction.removeAll()
        nextId = 1
    }

    private func registerHotkey(keyCode: Int, modifiers: NSEvent.ModifierFlags, action: HotkeyAction) {
        var hotKeyID = EventHotKeyID(signature: hotKeySignature, id: nextId)
        var ref: EventHotKeyRef?
        let carbon = carbonModifiers(from: modifiers)
        let status = RegisterEventHotKey(UInt32(keyCode), carbon, hotKeyID, GetEventDispatcherTarget(), 0, &ref)
        if status == noErr, let ref {
            hotKeyRefs[hotKeyID.id] = ref
            hotKeyIdToAction[hotKeyID.id] = action
            nextId += 1
        }
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, eventRef, userData in
            guard let eventRef, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            if status == noErr {
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotKey(id: hotKeyID.id)
            }
            return noErr
        }
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(GetEventDispatcherTarget(), handler, 1, &eventType, selfPtr, nil)
        handlerInstalled = true
    }

    private func handleHotKey(id: UInt32) {
        guard let action = hotKeyIdToAction[id] else { return }
        DispatchQueue.main.async { [onTrigger] in
            onTrigger(action)
        }
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbonFlags: UInt32 = 0
        if flags.contains(.command) {
            carbonFlags |= UInt32(cmdKey)
        }
        if flags.contains(.option) {
            carbonFlags |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            carbonFlags |= UInt32(controlKey)
        }
        if flags.contains(.shift) {
            carbonFlags |= UInt32(shiftKey)
        }
        return carbonFlags
    }
}

private let hotKeySignature: OSType = 0x4D4C4155
