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

@Test func layoutRoundTripsOriginsAndSkipsBadEntries() {
    let d = freshDefaults(); let s = LayoutStore(defaults: d)
    s.save(NotchLayoutPrefs(heights: [1: 320], origins: [1: NotchOrigin(x: 0.5, y: 0.2)]))
    let loaded = s.load()
    #expect(loaded.origins[1] == NotchOrigin(x: 0.5, y: 0.2))
    #expect(loaded.heights.isEmpty && d.object(forKey: LayoutStore.legacyHeightsKey) == nil)

    d.set(Data("not json".utf8), forKey: LayoutStore.originsKey)
    #expect(s.load().origins.isEmpty)
}

@Test func legacyHeightsAreIgnoredAndDropped() {
    let d = freshDefaults(); let s = LayoutStore(defaults: d)
    d.set(["1": 300.0], forKey: LayoutStore.legacyHeightsKey)
    #expect(s.load().heights.isEmpty)
    s.dropLegacyHeights()
    #expect(d.object(forKey: LayoutStore.legacyHeightsKey) == nil)
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
