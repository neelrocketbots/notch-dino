import Foundation
import NotchKit

public struct BestScoreStore: @unchecked Sendable {
    public static let key = "notchDino.best"
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// Anything that is not a non-negative integer reads as 0.
    public func load() -> Int { max(0, defaults.object(forKey: Self.key) as? Int ?? 0) }
    public func save(_ best: Int) { defaults.set(max(0, best), forKey: Self.key) }
}

/// The floating origin per display, through NotchKit's tolerant `NotchLayoutPrefs`. The island has one fixed height, so
/// heights are never stored.
public struct LayoutStore: @unchecked Sendable {
    /// Where earlier builds saved a height per display: no longer read, and removed on launch.
    public static let legacyHeightsKey = "notchDino.heights"
    public static let originsKey = "notchDino.origins"
    public static let floatingKey = "notchDino.floating"
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() -> NotchLayoutPrefs {
        let origins = defaults.data(forKey: Self.originsKey).map(Self.decodeOrigins) ?? [:]
        return NotchLayoutPrefs(storedHeights: [:], storedOrigins: origins)
    }

    /// Removes the heights earlier builds saved, so stale data does not linger.
    public func dropLegacyHeights() { defaults.removeObject(forKey: Self.legacyHeightsKey) }

    /// Decodes each entry on its own, so one malformed origin does not discard the valid ones.
    private static func decodeOrigins(_ data: Data) -> [String: NotchOrigin] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        var origins: [String: NotchOrigin] = [:]
        for (key, value) in object {
            guard let entry = try? JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed),
                  let origin = try? JSONDecoder().decode(NotchOrigin.self, from: entry) else { continue }
            origins[key] = origin
        }
        return origins
    }

    public func save(_ prefs: NotchLayoutPrefs) {
        defaults.set(try? JSONEncoder().encode(prefs.storedOrigins), forKey: Self.originsKey)
    }

    public func prefersFloating() -> Bool { defaults.bool(forKey: Self.floatingKey) }
    public func setPrefersFloating(_ floating: Bool) { defaults.set(floating, forKey: Self.floatingKey) }
}
