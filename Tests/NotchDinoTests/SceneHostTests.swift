import SpriteKit
import Testing
@testable import NotchDinoApp

@MainActor @Test func sceneHostPresentsTransparentSceneAndFollowsPause() {
    let scene = RunnerScene(islandSize: CGSize(width: 445, height: 282), band: 32)
    let view = SceneHost.makeView(scene: scene, paused: true)
    #expect(view.scene === scene)
    #expect(view.allowsTransparency)
    #expect(view.preferredFramesPerSecond == 120)
    #expect(view.isPaused)
    // SwiftUI's SpriteView ignores later isPaused changes; ours must apply them.
    SceneHost.update(view, paused: false)
    #expect(!view.isPaused)
    SceneHost.update(view, paused: true)
    #expect(view.isPaused)
}
