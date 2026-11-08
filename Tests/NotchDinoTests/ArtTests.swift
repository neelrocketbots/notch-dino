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

/// Opaque pixels and the mean warmth (red minus blue, 0…255) of the icon's inner 8 pt, which leaves out the bad ring.
private func iconStats(_ img: CGImage) -> (opaque: Int, warmth: Double) {
    let data = img.dataProvider!.data! as Data
    var opaque = 0, warmth = 0.0, n = 0
    for y in 0..<img.height {
        for x in 0..<img.width {
            let i = y * img.bytesPerRow + x * 4
            let a = Double(data[i + 3])
            if a > 128 { opaque += 1 }
            let dx = Double(x) - 34, dy = Double(y) - 34
            guard a > 128, dx * dx + dy * dy < 16 * 16 else { continue }
            // premultiplied: unpremultiply before comparing channels
            warmth += (Double(data[i]) - Double(data[i + 2])) * 255 / a
            n += 1
        }
    }
    return (opaque, n == 0 ? 0 : warmth / Double(n))
}

@Test(arguments: Pickup.allCases)
func everyPickupIconIsDrawnAndReadsGoodOrBad(p: Pickup) {
    let img = Art.pickup(p)
    #expect(img.width == 68 && img.height == 68)
    let stats = iconStats(img)
    #expect(stats.opaque > 600, "\(p) has \(stats.opaque) opaque pixels")
    if p.isGood { #expect(stats.warmth > 60, "\(p) warmth \(stats.warmth)") } else { #expect(stats.warmth < 25, "\(p) warmth \(stats.warmth)") }
}

@Test func pickupIconsAreAllDifferent() {
    let images = Pickup.allCases.map { Art.pickup($0).dataProvider!.data! as Data }
    #expect(Set(images).count == Pickup.allCases.count)
}
