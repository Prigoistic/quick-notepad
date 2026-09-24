import Carbon
import AppKit

enum HotkeyError: Error {
    case registrationFailed(OSStatus)
}

final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let onTrigger: () -> Void

    private static let signature: OSType = 0x514E_5450 // 'QNTP'
    private static let hotKeyID: UInt32 = 1

    init(onTrigger: @escaping () -> Void) throws {
        self.onTrigger = onTrigger

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.onTrigger()
            return noErr
        }, 1, &eventType, selfPointer, &eventHandler)

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: Self.hotKeyID)
        let cmdShiftMask = UInt32(cmdKey | shiftKey)
        let keyCodeForN: UInt32 = 45 // kVK_ANSI_N

        let status = RegisterEventHotKey(keyCodeForN, cmdShiftMask, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else {
            throw HotkeyError.registrationFailed(status)
        }
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}
