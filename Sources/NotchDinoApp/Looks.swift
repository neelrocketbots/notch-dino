import Foundation

/// Who flies. Every hero plays the same; only the art differs.
public enum Hero: String, CaseIterable, Sendable {
    case pip, moss, nova, coral, frost, sable, saffron, tide, rust, blossom

    public var name: String {
        switch self {
        case .pip: "Pip"
        case .moss: "Moss"
        case .nova: "Nova"
        case .coral: "Coral"
        case .frost: "Frost"
        case .sable: "Sable"
        case .saffron: "Saffron"
        case .tide: "Tide"
        case .rust: "Rust"
        case .blossom: "Blossom"
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
        case .coral: HeroPalette(body: 0xFF6F9A, light: 0xFFC2D5, shade: 0xC23F6C, wingFar: 0x7E1E44, spike: 0xE8457A,
                                 belly: 0xFFE6EE, horn: 0xFFB0C8, rib: 0x6A1236)
        case .frost: HeroPalette(body: 0xC9E4FF, light: 0xFFFFFF, shade: 0x7FA8D6, wingFar: 0x46699A, spike: 0x9FE6FF,
                                 belly: 0xFFFFFF, horn: 0xB8F2FF, rib: 0x2E5283)
        case .sable: HeroPalette(body: 0x4E4A56, light: 0xA8A2B2, shade: 0x2C2832, wingFar: 0x1E1B22, spike: 0xFF7A2E,
                                 belly: 0x7A7280, horn: 0xE6D6C4, rib: 0x8E8796)
        case .saffron: HeroPalette(body: 0xFFC23A, light: 0xFFEBA8, shade: 0xCC8710, wingFar: 0x86560A, spike: 0xFF8A3C,
                                   belly: 0xFFF6DC, horn: 0xFFF6DC, rib: 0x6A4006)
        case .tide: HeroPalette(body: 0x1FB5A6, light: 0x92EDDF, shade: 0x0D7770, wingFar: 0x094B47, spike: 0x5CCBF0,
                                belly: 0xD8FFF6, horn: 0xD8FFF6, rib: 0x063A36)
        case .rust: HeroPalette(body: 0xC4683A, light: 0xF4AE80, shade: 0x86391A, wingFar: 0x55210E, spike: 0x7C3A1C,
                                belly: 0xF6D8BC, horn: 0xEBD3B0, rib: 0x44190A)
        case .blossom: HeroPalette(body: 0xC6A4F0, light: 0xF0E4FF, shade: 0x8D68C6, wingFar: 0xB0679A, spike: 0xFF97C6,
                                   belly: 0xFFF0F8, horn: 0xFFD3E8, rib: 0xB4508C)
        }
    }
}

/// Where the run happens. Every map plays the same; the backdrop and the obstacles' material differ.
public enum MapTheme: String, CaseIterable, Sendable {
    case volcano, glacier, grove, dunes, skyisles, bamboo, crystal, storm, autumn, ruins

    public var name: String {
        switch self {
        case .volcano: "Ember Peaks"
        case .glacier: "Glacier"
        case .grove: "Night Grove"
        case .dunes: "Dune Sea"
        case .skyisles: "Sky Isles"
        case .bamboo: "Bamboo Vale"
        case .crystal: "Crystal Caves"
        case .storm: "Storm Coast"
        case .autumn: "Autumn Woods"
        case .ruins: "Lost Ruins"
        }
    }

    /// The first three maps draw in ArtSprites.swift and ArtBackdrop.swift; the rest in ArtMap*.swift.
    var isClassic: Bool { self == .volcano || self == .glacier || self == .grove }

    var palette: MapPalette {
        switch self {
        case .volcano:
            MapPalette(skyTop: (10, 4, 5), skyMid: (16, 6, 7), skyLow: (52, 16, 16), haze: (255, 90, 60), star: (255, 228, 214),
                       hill: 0x2E1416, hillFar: 0x221012, flora: 0x0E0506, ground: (34, 12, 13), groundLine: (255, 190, 170),
                       lit0: 0x33262A, lit1: 0x160F11, dark0: 0x080506, dark1: 0x120A0C, dark2: 0x2A1214,
                       chunkFill: 0x0B0708, chunkLit0: 0x3A2B30, chunkLit1: 0x140D0F, grain: 0.08, smoke: (40, 32, 34), fade: 46)
        case .glacier:
            MapPalette(skyTop: (3, 8, 18), skyMid: (6, 16, 32), skyLow: (20, 52, 70), haze: (120, 220, 255), star: (220, 240, 255),
                       hill: 0x1B3346, hillFar: 0x13253A, flora: 0x07131D, ground: (190, 220, 235), groundLine: (240, 250, 255),
                       lit0: 0xCFF3FF, lit1: 0x7CC7E8, dark0: 0x2B6F95, dark1: 0x3F8DB5, dark2: 0x9ADDF5,
                       chunkFill: 0x2D6E92, chunkLit0: 0xD8F6FF, chunkLit1: 0x5FAED3, grain: 0.35, smoke: (200, 215, 225), fade: 50)
        case .grove:
            MapPalette(skyTop: (8, 4, 14), skyMid: (18, 10, 30), skyLow: (26, 44, 30), haze: (150, 255, 140), star: (235, 225, 255),
                       hill: 0x1E2A1C, hillFar: 0x1A1626, flora: 0x080C08, ground: (22, 30, 18), groundLine: (170, 230, 150),
                       lit0: 0x6B4A33, lit1: 0x3E2A1C, dark0: 0x1A100A, dark1: 0x2A1A10, dark2: 0x4A3220,
                       chunkFill: 0x24301E, chunkLit0: 0x5E7A48, chunkLit1: 0x2A3A22, grain: 0.12, smoke: (30, 40, 30), fade: 48)
        case .dunes:
            MapPalette(skyTop: (24, 10, 40), skyMid: (84, 36, 86), skyLow: (236, 118, 64), haze: (255, 160, 90), star: (255, 230, 210),
                       hill: 0x5E2C42, hillFar: 0x45213F, flora: 0x1E0E1A, ground: (150, 92, 56), groundLine: (255, 200, 140),
                       lit0: 0xF2C48A, lit1: 0xD89358, dark0: 0xA85E36, dark1: 0xC0703E, dark2: 0x8A4A2C,
                       chunkFill: 0xB4683A, chunkLit0: 0xF0BE84, chunkLit1: 0xC98450, grain: 0.2, smoke: (120, 80, 60), fade: 58)
        case .skyisles:
            MapPalette(skyTop: (14, 22, 48), skyMid: (70, 100, 150), skyLow: (150, 176, 214), haze: (230, 240, 255), star: (240, 246, 255),
                       hill: 0x9CB1D2, hillFar: 0x7489B0, flora: 0x34466A, ground: (215, 228, 246), groundLine: (255, 255, 255),
                       lit0: 0x9C8A7E, lit1: 0x76655C, dark0: 0x3E3238, dark1: 0x4C3E42, dark2: 0x5E4E50,
                       chunkFill: 0x5A4A48, chunkLit0: 0x8C7A6E, chunkLit1: 0x5E4E48, grain: 0.15, smoke: (180, 190, 210), fade: 60)
        case .bamboo:
            MapPalette(skyTop: (6, 14, 12), skyMid: (34, 52, 46), skyLow: (104, 124, 112), haze: (210, 235, 215), star: (225, 240, 230),
                       hill: 0x2E423A, hillFar: 0x4A5E56, flora: 0x101C16, ground: (34, 58, 32), groundLine: (150, 210, 120),
                       lit0: 0xE2E89A, lit1: 0xA8C45A, dark0: 0x4E7A2A, dark1: 0x6A9638, dark2: 0x86AE48,
                       chunkFill: 0x6A9638, chunkLit0: 0xE2E89A, chunkLit1: 0x86AE48, grain: 0.2, smoke: (60, 80, 66), fade: 54)
        case .crystal:
            MapPalette(skyTop: (6, 2, 12), skyMid: (26, 10, 42), skyLow: (44, 20, 64), haze: (210, 120, 255), star: (230, 190, 255),
                       hill: 0x2C1A40, hillFar: 0x22142F, flora: 0x0E0618, ground: (36, 24, 48), groundLine: (200, 150, 255),
                       lit0: 0xF0D4FF, lit1: 0xB57CF0, dark0: 0x5A2A9A, dark1: 0x7A40C0, dark2: 0x9C64E0,
                       chunkFill: 0x4A3C46, chunkLit0: 0x7A6A72, chunkLit1: 0x4A3C46, grain: 0.3, smoke: (60, 40, 80), fade: 48)
        case .storm:
            MapPalette(skyTop: (6, 9, 14), skyMid: (34, 42, 54), skyLow: (66, 78, 92), haze: (170, 195, 220), star: (190, 210, 235),
                       hill: 0x1E2630, hillFar: 0x2C3642, flora: 0x0A0E14, ground: (38, 44, 52), groundLine: (170, 200, 225),
                       lit0: 0xB8C4D0, lit1: 0x8A96A4, dark0: 0x353C46, dark1: 0x4A525C, dark2: 0x66727E,
                       chunkFill: 0x3A424C, chunkLit0: 0xA8B4C0, chunkLit1: 0x5E6A76, grain: 0.25, smoke: (50, 58, 66), fade: 54)
        case .autumn:
            MapPalette(skyTop: (22, 10, 8), skyMid: (86, 42, 26), skyLow: (200, 116, 56), haze: (255, 170, 80), star: (255, 225, 180),
                       hill: 0x7A3418, hillFar: 0x55241A, flora: 0x24120A, ground: (64, 32, 16), groundLine: (255, 180, 100),
                       lit0: 0xFBF7EE, lit1: 0xE6DFD2, dark0: 0x9E958A, dark1: 0xB8B0A4, dark2: 0xD2CABE,
                       chunkFill: 0x6A4026, chunkLit0: 0xC89A64, chunkLit1: 0x8A5A34, grain: 0, smoke: (90, 50, 30), fade: 58)
        case .ruins:
            MapPalette(skyTop: (2, 8, 6), skyMid: (10, 28, 20), skyLow: (22, 50, 34), haze: (130, 230, 170), star: (220, 255, 232),
                       hill: 0x163024, hillFar: 0x10221A, flora: 0x06110A, ground: (40, 46, 38), groundLine: (170, 200, 160),
                       lit0: 0xC4C8B0, lit1: 0x9A9E86, dark0: 0x50544A, dark1: 0x62665A, dark2: 0x7A7E6C,
                       chunkFill: 0x6A6E5C, chunkLit0: 0xB8BCA4, chunkLit1: 0x80846E, grain: 0.2, smoke: (40, 56, 44), fade: 48)
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
    /// How far below the band, in points, the black fades into this sky: longer for brighter skies.
    let fade: CGFloat
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
