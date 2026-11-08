import AppKit

/// The island's window: borderless, never activates the app, sits above the menu bar, goes exactly where it is put.
/// It may become key only while the island is open (`allowsKey`), so keys reach the game without the frontmost app
/// losing focus.
public final class IslandPanel: NSPanel {
    public var allowsKey = false

    public init(size: CGSize) {
        super.init(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        animationBehavior = .none
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
    }

    public override var canBecomeKey: Bool { allowsKey }
    public override var canBecomeMain: Bool { false }
    public override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    /// Gives up key status without activating anything: AppKit forbids calling `resignKey()` directly.
    public func dropKey() {
        allowsKey = false
        guard isKeyWindow else { return }
        orderOut(nil)
        orderFrontRegardless()
    }
}
