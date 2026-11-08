import Foundation

public enum RefuseReason: String, Sendable, CaseIterable { case version, full }
public enum ByeReason: String, Sendable, CaseIterable { case left, quit, timeout, desync, pauseLimit }

/// Everything two racing Macs say to each other (protocol 1, spec §5). `hero` and `map` are `rawValue`s; RaceCore
/// doesn't know the art. `welcome` carries the host's world width so both Macs race the same `World`.
public enum RaceMessage: Equatable, Sendable {
    case hello(proto: Int, rules: Int, name: String, hero: String)
    case welcome(name: String, hero: String, map: String, width: Double)
    case refuse(RefuseReason)
    case ping(t: Double)
    case pong(t: Double)
    case start(seed: UInt64, inMs: Int)
    case flap(step: Int)
    case pause(atStep: Int)
    case resume(inMs: Int)
    case crashed(step: Int, score: Int)
    case rematch
    case bye(ByeReason)

    public static let protocolVersion = 1
}

/// Bounds a well-behaved peer never gets near. A message outside them is dropped as malformed.
public enum RaceLimits {
    public static let maxStep = 10_000_000
    public static let maxScore = 10_000_000
    public static let maxInMs = 5_000
    public static let maxVersion = 1_000
    public static let widths: ClosedRange<Double> = 50...5_000
    public static let maxNameCharacters = 12
    public static let maxNameBytes = 64
    public static let maxTokenLength = 32
}

public enum RaceName {
    /// Control characters, line breaks and text-direction overrides removed; trimmed; at most 12 characters and 64
    /// UTF-8 bytes (so a name of stacked accents can't fill a frame); "Player" when nothing is left.
    public static func clean(_ raw: String) -> String {
        var scalars = String.UnicodeScalarView()
        for u in raw.unicodeScalars where !isUnsafe(u) { scalars.append(u) }
        var name = String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
        name = String(name.prefix(RaceLimits.maxNameCharacters))
        while name.utf8.count > RaceLimits.maxNameBytes { name.removeLast() }
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Player" : name
    }

    static func isUnsafe(_ u: Unicode.Scalar) -> Bool {
        switch u.properties.generalCategory {
        case .control, .lineSeparator, .paragraphSeparator: return true
        default: return (0x202A...0x202E).contains(u.value) || (0x2066...0x2069).contains(u.value)
        }
    }

    /// A hero or map raw value: 1…32 ASCII letters and digits.
    public static func isToken(_ s: String) -> Bool {
        !s.isEmpty && s.unicodeScalars.count <= RaceLimits.maxTokenLength
            && s.unicodeScalars.allSatisfy { $0.isASCII && ($0.properties.isAlphabetic || ("0"..."9").contains($0)) }
    }
}

/// The JSON shape: one object with a `type` and that type's fields. The seed travels as a decimal string: JSON
/// numbers are doubles to many parsers and would lose bits of a 64-bit seed.
struct RaceWire: Codable {
    var type: String
    var proto: Int?
    var rules: Int?
    var name: String?
    var hero: String?
    var map: String?
    var width: Double?
    var reason: String?
    var t: Double?
    var seed: String?
    var inMs: Int?
    var step: Int?
    var atStep: Int?
    var score: Int?
    init(type: String) { self.type = type }
}

extension RaceMessage {
    public func json() -> Data {
        var w: RaceWire
        switch self {
        case .hello(let proto, let rules, let name, let hero):
            w = RaceWire(type: "hello"); w.proto = proto; w.rules = rules; w.name = name; w.hero = hero
        case .welcome(let name, let hero, let map, let width):
            w = RaceWire(type: "welcome"); w.name = name; w.hero = hero; w.map = map; w.width = width
        case .refuse(let reason):
            w = RaceWire(type: "refuse"); w.reason = reason.rawValue
        case .ping(let t):
            w = RaceWire(type: "ping"); w.t = t
        case .pong(let t):
            w = RaceWire(type: "pong"); w.t = t
        case .start(let seed, let inMs):
            w = RaceWire(type: "start"); w.seed = String(seed); w.inMs = inMs
        case .flap(let step):
            w = RaceWire(type: "flap"); w.step = step
        case .pause(let atStep):
            w = RaceWire(type: "pause"); w.atStep = atStep
        case .resume(let inMs):
            w = RaceWire(type: "resume"); w.inMs = inMs
        case .crashed(let step, let score):
            w = RaceWire(type: "crashed"); w.step = step; w.score = score
        case .rematch:
            w = RaceWire(type: "rematch")
        case .bye(let reason):
            w = RaceWire(type: "bye"); w.reason = reason.rawValue
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(w)) ?? Data()
    }

    /// Decodes and validates one message. Malformed JSON, an unknown type, a missing field or a value out of range
    /// gives nil (the caller drops it). Names are cleaned.
    public init?(json data: Data) {
        guard let w = try? JSONDecoder().decode(RaceWire.self, from: data) else { return nil }
        func inRange(_ v: Int?, _ r: ClosedRange<Int>) -> Int? { v.flatMap { r.contains($0) ? $0 : nil } }
        func step(_ v: Int?) -> Int? { inRange(v, 0...RaceLimits.maxStep) }
        func ms(_ v: Int?) -> Int? { inRange(v, 0...RaceLimits.maxInMs) }
        func version(_ v: Int?) -> Int? { inRange(v, 0...RaceLimits.maxVersion) }
        func token(_ v: String?) -> String? { v.flatMap { RaceName.isToken($0) ? $0 : nil } }
        func time(_ v: Double?) -> Double? { v.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil } }
        switch w.type {
        case "hello":
            guard let p = version(w.proto), let r = version(w.rules), let n = w.name, let h = token(w.hero) else { return nil }
            self = .hello(proto: p, rules: r, name: RaceName.clean(n), hero: h)
        case "welcome":
            guard let n = w.name, let h = token(w.hero), let m = token(w.map), let width = w.width,
                  RaceLimits.widths.contains(width) else { return nil }
            self = .welcome(name: RaceName.clean(n), hero: h, map: m, width: width)
        case "refuse":
            guard let r = w.reason.flatMap(RefuseReason.init(rawValue:)) else { return nil }
            self = .refuse(r)
        case "ping":
            guard let t = time(w.t) else { return nil }
            self = .ping(t: t)
        case "pong":
            guard let t = time(w.t) else { return nil }
            self = .pong(t: t)
        case "start":
            guard let seed = w.seed.flatMap({ UInt64($0) }), let i = ms(w.inMs) else { return nil }
            self = .start(seed: seed, inMs: i)
        case "flap":
            guard let s = step(w.step) else { return nil }
            self = .flap(step: s)
        case "pause":
            guard let s = step(w.atStep) else { return nil }
            self = .pause(atStep: s)
        case "resume":
            guard let i = ms(w.inMs) else { return nil }
            self = .resume(inMs: i)
        case "crashed":
            guard let s = step(w.step), let score = inRange(w.score, 0...RaceLimits.maxScore) else { return nil }
            self = .crashed(step: s, score: score)
        case "rematch":
            self = .rematch
        case "bye":
            guard let r = w.reason.flatMap(ByeReason.init(rawValue:)) else { return nil }
            self = .bye(r)
        default:
            return nil
        }
    }
}
