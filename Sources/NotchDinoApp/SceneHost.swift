import SpriteKit
import SwiftUI

/// Hosts the RunnerScene in an SKView we control. SwiftUI's `SpriteView` reads `isPaused` only when it is created, so a
/// view created while the island was folded never started drawing after it opened. Here the pause follows the island:
/// running while open, frozen on its last frame while folded, which costs nothing.
struct SceneHost: NSViewRepresentable {
    let scene: SKScene
    let paused: Bool

    static func makeView(scene: SKScene, paused: Bool) -> SKView {
        let view = SKView()
        view.allowsTransparency = true
        view.preferredFramesPerSecond = 120
        view.ignoresSiblingOrder = true
        view.presentScene(scene)
        view.isPaused = paused
        return view
    }

    static func update(_ view: SKView, paused: Bool) {
        if view.isPaused != paused { view.isPaused = paused }
    }

    func makeNSView(context: Context) -> SKView { Self.makeView(scene: scene, paused: paused) }
    func updateNSView(_ view: SKView, context: Context) { Self.update(view, paused: paused) }
}
