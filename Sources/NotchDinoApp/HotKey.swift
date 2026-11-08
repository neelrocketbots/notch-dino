import Carbon.HIToolbox

/// A global hot-key through Carbon's `RegisterEventHotKey`. It needs no Accessibility or Input Monitoring permission.
/// `init` returns nil when the combination cannot be registered.
@MainActor public final class HotKey {
    public static let controlOption = UInt32(controlKey | optionKey)
    public static let spaceKeyCode: UInt32 = 49

    private static var actions: [UInt32: @MainActor () -> Void] = [:]
    private static var handlerInstalled = false
    private var ref: EventHotKeyRef?
    private let id: UInt32

    public init?(keyCode: UInt32, modifiers: UInt32, id: UInt32 = 1, action: @escaping @MainActor () -> Void) {
        self.id = id
        guard Self.installHandler() else { return nil }
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4E44_494E), id: id) // "NDIN"
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr, let hotKeyRef else { return nil }
        ref = hotKeyRef
        Self.actions[id] = action
    }

    public func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        Self.actions[id] = nil
    }

    private static func installHandler() -> Bool {
        if handlerInstalled { return true }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var pressed = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed)
            let id = pressed.id
            // Carbon delivers application events on the main thread.
            MainActor.assumeIsolated { HotKey.actions[id]?() }
            return noErr
        }, 1, &spec, nil, nil)
        handlerInstalled = status == noErr
        return handlerInstalled
    }
}
