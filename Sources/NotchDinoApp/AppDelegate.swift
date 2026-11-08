import AppKit
import NotchKit
import os
import SwiftUI

/// A hosting view that takes the first click (the app is never active) and never sizes the window.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// The panel's one frame owner (NotchKit invariant 1). It takes the mouse only over `hitRect()` (invariant 4); every
/// other click reaches the apps below.
final class IslandContainerView: NSView {
    var hitRect: () -> CGRect = { .zero }
    var isOpen: () -> Bool = { false }
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        let topLeft = CGPoint(x: local.x, y: bounds.height - local.y)
        // Folded: the notch exactly. Open: the island plus NotchKit's margin.
        let margin = isOpen() ? NotchHitRect.margin : 0
        guard NotchHitRect.contains(point: topLeft, islandRect: hitRect(), margin: margin) else { return nil }
        return super.hitTest(point)
    }
}

@MainActor public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: IslandModel?
    private var panel: IslandPanel?
    private var hotKey: HotKey?
    private var statusItem: StatusItem?
    private var monitors: [Any] = []
    private let log = Logger(subsystem: "NotchDino", category: "app")

    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let display = DisplayPicker.pick(NotchScreens.displays())
        let model = IslandModel(display: display, best: BestScoreStore(), layout: LayoutStore(),
                                seed: UInt64(Date().timeIntervalSince1970))
        let panel = IslandPanel(size: model.panelSize)
        let container = IslandContainerView(frame: CGRect(origin: .zero, size: model.panelSize))
        container.hitRect = { [weak model] in MainActor.assumeIsolated { model?.hitRect ?? .zero } }
        container.isOpen = { [weak model] in MainActor.assumeIsolated { model?.isOpen ?? false } }
        let host = FirstMouseHostingView(rootView: IslandView(model: model))
        host.sizingOptions = []
        host.safeAreaRegions = []
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        container.autoresizesSubviews = true
        panel.contentView = container
        model.panel = panel
        model.placePanel()
        panel.orderFrontRegardless()
        self.model = model
        self.panel = panel

        installStatusItem()
        installHotKey()
        installMonitors()
        installObservers()
    }

    private func installStatusItem() {
        statusItem = StatusItem(isOpen: { [weak self] in self?.model?.isOpen ?? false },
                                onToggle: { [weak self] in self?.model?.handle(.hotKey) },
                                look: { [weak self] in (self?.model?.hero ?? .pip, self?.model?.map ?? .volcano) },
                                onHero: { [weak self] in self?.model?.choose(hero: $0) },
                                onMap: { [weak self] in self?.model?.choose(map: $0) })
    }

    private func installHotKey() {
        hotKey = HotKey(keyCode: HotKey.spaceKeyCode, modifiers: HotKey.controlOption) { [weak self] in
            self?.model?.handle(.hotKey)
        }
        if hotKey == nil { log.error("⌃⌥Space is unavailable; click the notch to open") }
    }

    private func installMonitors() {
        // AppKit calls monitors on the main thread; the closures are not annotated, so hop with assumeIsolated.
        if let m = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            // NSEvent is not Sendable: only a Bool crosses the isolation boundary, the event itself stays here.
            nonisolated(unsafe) let e = event
            let consumed = MainActor.assumeIsolated { self?.consumes(e) ?? false }
            return consumed ? nil : event
        }) { monitors.append(m) }
    }

    /// Keys are consumed only while open: KeyRouter returns nil when folded, so the event passes through.
    private func consumes(_ event: NSEvent) -> Bool {
        guard let model,
              let action = KeyRouter.action(keyCode: event.keyCode, command: event.modifierFlags.contains(.command),
                                            isOpen: model.isOpen) else { return false }
        switch action {
        case .quit: NSApp.terminate(nil)
        case .island(let e): if !event.isARepeat { model.handle(e) }
        }
        return true
    }

    private func installObservers() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.model?.handle(.lostKey) }
        }
        nc.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.model?.rehome(displays: NotchScreens.displays()) }
        }
        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.model?.handle(.autoPause) }
            }
        }
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("com.apple.screenIsLocked"),
                                                            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.model?.handle(.autoPause) }
        }
    }
}
