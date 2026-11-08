import AppKit

/// The menu-bar item. Always shown, so the game has a way in that does not depend on the notch, which other notch
/// apps may already be using. Its menu toggles the island the same way ⌃⌥Space does.
@MainActor final class StatusItem: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let toggleItem = NSMenuItem(title: "Play", action: #selector(toggle), keyEquivalent: "")
    private let isOpen: () -> Bool
    private let onToggle: () -> Void

    init(isOpen: @escaping () -> Bool, onToggle: @escaping () -> Void) {
        self.isOpen = isOpen
        self.onToggle = onToggle
        super.init()
        if let button = item.button {
            let image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "Notch Dino")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Notch Dino"
        }
        let menu = NSMenu()
        menu.delegate = self
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Notch Dino", action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        item.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        toggleItem.title = isOpen() ? "Fold (⌃⌥Space)" : "Play (⌃⌥Space)"
    }

    @objc private func toggle() { onToggle() }
}
