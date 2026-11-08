import Foundation
import NotchKit
import Testing
@testable import NotchDinoApp

func freshDefaults() -> UserDefaults { UserDefaults(suiteName: "notchDino.tests.\(UUID().uuidString)")! }

@Test func bestRoundTrips() {
    let d = freshDefaults(); let s = BestScoreStore(defaults: d)
    #expect(s.load() == 0)
    s.save(31); #expect(s.load() == 31)
}

@Test func corruptBestLoadsAsZero() {
    let d = freshDefaults()
    d.set("abc", forKey: BestScoreStore.key); #expect(BestScoreStore(defaults: d).load() == 0)
    d.set(-5, forKey: BestScoreStore.key); #expect(BestScoreStore(defaults: d).load() == 0)
}

@Test func layoutRoundTripsAndSkipsBadEntries() {
    let d = freshDefaults(); let s = LayoutStore(defaults: d)
    s.save(NotchLayoutPrefs(heights: [1: 320], origins: [1: NotchOrigin(x: 0.5, y: 0.2)]))
    let loaded = s.load()
    #expect(loaded.heights[1] == 320 && loaded.origins[1] == NotchOrigin(x: 0.5, y: 0.2))

    d.set(["1": 300.0, "01": 200.0, "x": 100.0], forKey: LayoutStore.heightsKey)
    d.set(Data("not json".utf8), forKey: LayoutStore.originsKey)
    let tolerant = s.load()
    #expect(tolerant.heights == [1: 300] && tolerant.origins.isEmpty)
}

@Test func floatingPreference() {
    let s = LayoutStore(defaults: freshDefaults())
    #expect(!s.prefersFloating())
    s.setPrefersFloating(true); #expect(s.prefersFloating())
}

@Test func mixedOriginsKeepTheGoodEntry() {
    let d = freshDefaults(); let s = LayoutStore(defaults: d)
    d.set(Data(#"{"1":{"x":0.5,"y":0.2},"2":{"x":"a","y":0}}"#.utf8), forKey: LayoutStore.originsKey)
    #expect(s.load().origins == [1: NotchOrigin(x: 0.5, y: 0.2)])
}
