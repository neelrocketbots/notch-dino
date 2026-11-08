import AppKit

/// The menu-bar item. Always shown, so the game has a way in that does not depend on the notch, which other notch
/// apps may already be using. Its menu toggles the island the same way ⌃⌥Space does, and picks the hero and the map.
@MainActor final class StatusItem: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let toggleItem = NSMenuItem(title: "Play", action: #selector(toggle), keyEquivalent: "")
    private let heroMenu = NSMenu(title: "Hero")
    private let mapMenu = NSMenu(title: "Map")
    private let isOpen: () -> Bool
    private let onToggle: () -> Void
    private let look: () -> (hero: Hero, map: MapTheme)
    private let onHero: (Hero) -> Void
    private let onMap: (MapTheme) -> Void

    init(isOpen: @escaping () -> Bool, onToggle: @escaping () -> Void,
         look: @escaping () -> (hero: Hero, map: MapTheme), onHero: @escaping (Hero) -> Void, onMap: @escaping (MapTheme) -> Void) {
        self.isOpen = isOpen
        self.onToggle = onToggle
        self.look = look
        self.onHero = onHero
        self.onMap = onMap
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
        for h in Hero.allCases {
            let i = NSMenuItem(title: h.name, action: #selector(pickHero(_:)), keyEquivalent: "")
            i.target = self; i.representedObject = h.rawValue; heroMenu.addItem(i)
        }
        for m in MapTheme.allCases {
            let i = NSMenuItem(title: m.name, action: #selector(pickMap(_:)), keyEquivalent: "")
            i.target = self; i.representedObject = m.rawValue; mapMenu.addItem(i)
        }
        let heroItem = NSMenuItem(title: "Hero", action: nil, keyEquivalent: ""); heroItem.submenu = heroMenu
        let mapItem = NSMenuItem(title: "Map", action: nil, keyEquivalent: ""); mapItem.submenu = mapMenu
        menu.addItem(heroItem)
        menu.addItem(mapItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Notch Dino", action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        item.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        toggleItem.title = isOpen() ? "Fold (⌃⌥Space)" : "Play (⌃⌥Space)"
        let current = look()
        for i in heroMenu.items { i.state = (i.representedObject as? String) == current.hero.rawValue ? .on : .off }
        for i in mapMenu.items { i.state = (i.representedObject as? String) == current.map.rawValue ? .on : .off }
    }

    @objc private func toggle() { onToggle() }

    @objc private func pickHero(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let h = Hero(rawValue: raw) { onHero(h) }
    }

    @objc private func pickMap(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let m = MapTheme(rawValue: raw) { onMap(m) }
    }
}
