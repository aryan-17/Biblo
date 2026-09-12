import Carbon.HIToolbox
import Foundation

// Global C function — required because @convention(c) closures can't capture context.
// userData carries an unretained HotkeyManager pointer.
private func carbonEventHandler(
    _ handlerRef: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event = event, let userData = userData else { return noErr }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    switch GetEventKind(event) {
    case UInt32(kEventHotKeyPressed):
        DispatchQueue.main.async { manager.onKeyDown?() }
    case UInt32(kEventHotKeyReleased):
        DispatchQueue.main.async { manager.onKeyUp?() }
    default:
        break
    }
    return noErr
}

// ─── HotkeyManager ───────────────────────────────────────────────────────────

final class HotkeyManager {
    var onKeyDown: (() -> Void)?
    var onKeyUp:   (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var selfPtr: UnsafeMutableRawPointer?

    /// Register a global hotkey. keyCode uses Carbon virtual key codes.
    /// F13 = 105, F14 = 107, F15 = 113
    func register(keyCode: UInt32, modifiers: UInt32 = 0) {
        let hkID = EventHotKeyID(signature: fourCC("BIBL"), id: 1)
        let status = RegisterEventHotKey(
            keyCode, modifiers, hkID,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
        guard status == noErr else {
            print("Biblo: failed to register hotkey, OSStatus \(status)")
            return
        }

        var specs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                          eventKind: OSType(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                          eventKind: OSType(kEventHotKeyReleased)),
        ]

        // Retain self so the pointer stays valid for the lifetime of the handler.
        // Balanced by a release in deinit.
        selfPtr = Unmanaged.passRetained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            carbonEventHandler,
            specs.count,
            &specs,
            selfPtr,
            &eventHandlerRef
        )
    }

    deinit {
        if let ref = hotKeyRef        { UnregisterEventHotKey(ref) }
        if let ref = eventHandlerRef  { RemoveEventHandler(ref) }
        if let ptr = selfPtr          { Unmanaged<HotkeyManager>.fromOpaque(ptr).release() }
    }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

private func fourCC(_ s: String) -> OSType {
    var result: OSType = 0
    for byte in s.utf8.prefix(4) { result = result << 8 | OSType(byte) }
    return result
}
