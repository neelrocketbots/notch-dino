import Foundation
import CoreGraphics
import RunnerCore
import Testing
@testable import NotchDinoApp

@Test func spritesRenderAtTwiceTheirPointSize() {
    #expect(Art.pip(.wingUp).width == 104 && Art.pip(.wingUp).height == 88)
    #expect(Art.shard().width == 36 && Art.shard().height == 640)
    #expect(Art.chunk().width == 52)
    for p in Pickup.allCases { #expect(Art.pickup(p).width == 68) }
    #expect(Art.breath().width == 68 && Art.puff().width == 28 && Art.dot().width == 8)
}

@Test func pipIsNotBlank() {
    let img = Art.pip(.wingDown)
    let data = img.dataProvider!.data! as Data
    // the body centre pixel (27,25 pt → 54,50 px) is opaque
    let i = (50 * img.bytesPerRow) + 54 * 4
    #expect(data[i + 3] > 200)
}

@Test func backdropTexturesHaveExpectedSizes() {
    #expect(Art.sky(size: CGSize(width: 445, height: 282), fieldTop: 34, fieldHeight: 240, groundY: 259.6).width == 890)
    #expect(Art.stars().width == 1400 && Art.volcanoes().width == 920 && Art.cycads().width == 600)
    #expect(Art.ground(width: 489, height: 24).width == 978)
    #expect(Art.smoke(size: CGSize(width: 320, height: 260)).height == 520)
}
