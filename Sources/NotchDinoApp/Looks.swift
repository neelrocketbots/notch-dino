import Foundation

/// Who flies. Every hero plays the same; only the art differs.
public enum Hero: String, CaseIterable, Sendable {
    case pip, moss, nova

    public var name: String {
        switch self {
        case .pip: "Pip"
        case .moss: "Moss"
        case .nova: "Nova"
        }
    }

    var palette: HeroPalette {
        switch self {
        case .pip: HeroPalette(body: 0xFF5A3C, light: 0xFFB08A, shade: 0xB8321E, wingFar: 0x7E2014, spike: 0xE0442A,
                               belly: 0xFFE2C8, horn: 0xFFE2C8, rib: 0x64140A)
        case .moss: HeroPalette(body: 0x5DBB4A, light: 0xB9EA8E, shade: 0x2E7A2A, wingFar: 0x1F4F1C, spike: 0xC8E05A,
                                belly: 0xF1F5C8, horn: 0x8FD45A, rib: 0x173D14)
        case .nova: HeroPalette(body: 0x8A63FF, light: 0xC9B6FF, shade: 0x4B2DB0, wingFar: 0x2C1A6E, spike: 0xFFC94D,
                                belly: 0xEDE6FF, horn: 0xFFD66B, rib: 0x221255)
        }
    }
}

/// Where the run happens. Every map plays the same; the backdrop and the obstacles' material differ.
public enum MapTheme: String, CaseIterable, Sendable {
    case volcano, glacier, grove

    public var name: String {
        switch self {
        case .volcano: "Ember Peaks"
        case .glacier: "Glacier"
        case .grove: "Night Grove"
        }
    }

    var palette: MapPalette {
        switch self {
        case .volcano:
            MapPalette(skyTop: (10, 4, 5), skyMid: (16, 6, 7), skyLow: (52, 16, 16), haze: (255, 90, 60), star: (255, 228, 214),
                       hill: 0x2E1416, hillFar: 0x221012, flora: 0x0E0506, ground: (34, 12, 13), groundLine: (255, 190, 170),
                       lit0: 0x33262A, lit1: 0x160F11, dark0: 0x080506, dark1: 0x120A0C, dark2: 0x2A1214,
                       chunkFill: 0x0B0708, chunkLit0: 0x3A2B30, chunkLit1: 0x140D0F, grain: 0.08, smoke: (40, 32, 34))
        case .glacier:
            MapPalette(skyTop: (3, 8, 18), skyMid: (6, 16, 32), skyLow: (20, 52, 70), haze: (120, 220, 255), star: (220, 240, 255),
                       hill: 0x1B3346, hillFar: 0x13253A, flora: 0x07131D, ground: (190, 220, 235), groundLine: (240, 250, 255),
                       lit0: 0xCFF3FF, lit1: 0x7CC7E8, dark0: 0x2B6F95, dark1: 0x3F8DB5, dark2: 0x9ADDF5,
                       chunkFill: 0x2D6E92, chunkLit0: 0xD8F6FF, chunkLit1: 0x5FAED3, grain: 0.35, smoke: (200, 215, 225))
        case .grove:
            MapPalette(skyTop: (8, 4, 14), skyMid: (18, 10, 30), skyLow: (26, 44, 30), haze: (150, 255, 140), star: (235, 225, 255),
                       hill: 0x1E2A1C, hillFar: 0x1A1626, flora: 0x080C08, ground: (22, 30, 18), groundLine: (170, 230, 150),
                       lit0: 0x6B4A33, lit1: 0x3E2A1C, dark0: 0x1A100A, dark1: 0x2A1A10, dark2: 0x4A3220,
                       chunkFill: 0x24301E, chunkLit0: 0x5E7A48, chunkLit1: 0x2A3A22, grain: 0.12, smoke: (30, 40, 30))
        }
    }
}

struct HeroPalette {
    let body, light, shade, wingFar, spike, belly, horn, rib: UInt32
}

struct MapPalette {
    typealias RGB = (CGFloat, CGFloat, CGFloat)
    let skyTop, skyMid, skyLow, haze, star: RGB
    let hill, hillFar, flora: UInt32
    let ground, groundLine: RGB
    /// Obstacle material: the lit face, the shadow face, and the floating chunk.
    let lit0, lit1, dark0, dark1, dark2: UInt32
    let chunkFill, chunkLit0, chunkLit1: UInt32
    /// Strength of the surface lines (obsidian ridges, ice glints, bark).
    let grain: CGFloat
    let smoke: RGB
}

/// The chosen hero and map, under `notchDino.hero` and `notchDino.map`. Anything unknown reads as the default.
public struct LookStore: @unchecked Sendable {
    public static let heroKey = "notchDino.hero"
    public static let mapKey = "notchDino.map"
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func hero() -> Hero { defaults.string(forKey: Self.heroKey).flatMap(Hero.init(rawValue:)) ?? .pip }
    public func map() -> MapTheme { defaults.string(forKey: Self.mapKey).flatMap(MapTheme.init(rawValue:)) ?? .volcano }
    public func save(hero: Hero) { defaults.set(hero.rawValue, forKey: Self.heroKey) }
    public func save(map: MapTheme) { defaults.set(map.rawValue, forKey: Self.mapKey) }
}
