import Cocoa
import Carbon


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

    
    var onHotKey: (() -> Void)?

    
    func registerDefault() {
        let combo = HotKeyCombination(keyCode: 17, modifiers: UInt32(shiftKey | cmdKey))
        register(hotKey: combo)
    }

    
    func register(hotKey: HotKeyCombination) {
        
        unregister()

        
        if eventHandlerRef == nil {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
                return HotKeyManager.handleHotKeyEvent(nextHandler, theEvent, userData)
            }, 1, &eventType, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &eventHandlerRef)
            if status != noErr {
                NSLog("Failed to install hot key event handler: %d", status)
            }
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x48544B31), id: UInt32(1)) 
        let status = RegisterEventHotKey(hotKey.keyCode, hotKey.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            NSLog("Failed to register hot key: %d", status)
        }
    }

    
    func unregister() {
        if let hk = hotKeyRef {
            UnregisterEventHotKey(hk)
            hotKeyRef = nil
        }
        
    }

    @MainActor deinit {
        unregister()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    

    private static func handleHotKeyEvent(_ nextHandler: EventHandlerCallRef?, _ theEvent: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
        guard let userData = userData else { return noErr }
        let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
        manager.onHotKey?()
        return noErr
    }
}