import Cocoa
import Carbon

// Represents a global hot key combination using Carbon key codes and modifiers.
struct HotKeyCombination {
    let keyCode: UInt32
    let modifiers: UInt32
}

@MainActor
final class HotKeyManager {
    static let shared = HotKeyManager()
    private init() {}

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    // Called when the registered hot key is pressed.
    var onHotKey: (() -> Void)?

    // Registers the default Option+Command+T hot key.
    func registerDefault() {
        let combo = HotKeyCombination(keyCode: 17, modifiers: UInt32(cmdKey | optionKey))
        register(hotKey: combo)
    }

    // Registers the provided hot key combination globally.
    func register(hotKey: HotKeyCombination) {
        // Unregister any existing hotkey
        unregister()

        // Install handler if needed
        if eventHandlerRef == nil {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
                return HotKeyManager.handleHotKeyEvent(nextHandler, theEvent, userData)
            }, 1, &eventType, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &eventHandlerRef)
            if status != noErr {
                NSLog("Failed to install hot key event handler: %d", status)
            }
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x48544B31), id: UInt32(1)) // 'HTK1'
        let status = RegisterEventHotKey(hotKey.keyCode, hotKey.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            NSLog("Failed to register hot key: %d", status)
        }
    }

    // Unregisters the current hot key and removes the handler if present.
    func unregister() {
        if let hk = hotKeyRef {
            UnregisterEventHotKey(hk)
            hotKeyRef = nil
        }
        // Keep handler installed for reuse; it is lightweight and safe.
    }

    @MainActor deinit {
        unregister()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    // MARK: - Event Routing

    private static func handleHotKeyEvent(_ nextHandler: EventHandlerCallRef?, _ theEvent: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
        guard let userData = userData else { return noErr }
        let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
        manager.onHotKey?()
        return noErr
    }
}

/*
Usage:
In AppDelegate.applicationDidFinishLaunching:

HotKeyManager.shared.onHotKey = { /* show your UI */ }
HotKeyManager.shared.registerDefault()
*/

