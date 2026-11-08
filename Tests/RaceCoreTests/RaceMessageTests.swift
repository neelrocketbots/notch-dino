import Foundation
import Testing
@testable import RaceCore

private let every: [RaceMessage] = [
    .hello(proto: 1, rules: 3, name: "Neel", hero: "pip"),
    .welcome(name: "Ana", hero: "moss", map: "glacier", width: 351.25),
    .refuse(.version), .refuse(.full),
    .ping(t: 12.5), .pong(t: 12.5),
    .start(seed: UInt64.max, inMs: 2100), .start(seed: 0, inMs: 0),
    .flap(step: 0), .flap(step: 14_400),
    .pause(atStep: 512), .resume(inMs: 2100),
    .crashed(step: 900, score: 17),
    .rematch,
] + ByeReason.allCases.map { RaceMessage.bye($0) }

private func json(_ s: String) -> Data { Data(s.utf8) }
private func header(_ n: UInt32) -> Data { withUnsafeBytes(of: n.bigEndian) { Data($0) } }
private func framed(_ list: [RaceMessage]) -> Data { list.reduce(Data()) { $0 + RaceFrame.encode($1) } }

@Suite struct RaceMessageTests {
    @Test func everyMessageRoundTrips() {
        for m in every { #expect(RaceMessage(json: m.json()) == m, "\(m)") }
    }

    @Test func framesAreALengthThenTheJSON() {
        let m = RaceMessage.flap(step: 7)
        let f = RaceFrame.encode(m)
        #expect(f.prefix(4) == header(UInt32(m.json().count)))
        #expect(f.dropFirst(4) == m.json())
    }

    @Test func framesSplitAndCoalescedDecodeOnce() throws {
        let bytes = framed(every)
        var whole = FrameReader()
        #expect(try whole.append(bytes).compactMap(RaceMessage.init(json:)) == every)

        var byByte = FrameReader(), got: [RaceMessage] = []
        for b in bytes { got += try byByte.append(Data([b])).compactMap(RaceMessage.init(json:)) }
        #expect(got == every)

        var uneven = FrameReader(), got2: [RaceMessage] = []
        var i = 0, chunk = 1
        while i < bytes.count {
            let end = min(bytes.count, i + chunk)
            got2 += try uneven.append(bytes.subdata(in: i..<end)).compactMap(RaceMessage.init(json:))
            i = end
            chunk = chunk % 37 + 5
        }
        #expect(got2 == every)
    }

    @Test func aFrameOver1KBIsRejected() throws {
        var big = FrameReader()
        #expect(throws: FrameTooLarge.self) { _ = try big.append(header(1025)) }
        var edge = FrameReader()
        #expect(try edge.append(header(1024)).isEmpty)
    }

    @Test func malformedAndUnknownMessagesAreDropped() {
        let bad = ["", "{", "[]", "null", #"{"step":1}"#, #"{"type":"warp","step":1}"#, #"{"type":"flap"}"#,
                   #"{"type":"flap","step":"1"}"#, #"{"type":"start","seed":"-1","inMs":10}"#,
                   #"{"type":"start","seed":"12x","inMs":10}"#, #"{"type":"bye","reason":"bored"}"#,
                   #"{"type":"refuse","reason":"busy"}"#, #"{"type":"hello","proto":1,"rules":3,"hero":"pip"}"#]
        for s in bad { #expect(RaceMessage(json: json(s)) == nil, "\(s)") }
    }

    @Test func outOfRangeMessagesAreRejected() {
        let bad = [#"{"type":"flap","step":-1}"#, #"{"type":"flap","step":10000001}"#,
                   #"{"type":"pause","atStep":-5}"#, #"{"type":"resume","inMs":5001}"#,
                   #"{"type":"start","seed":"7","inMs":-1}"#, #"{"type":"crashed","step":5,"score":-1}"#,
                   #"{"type":"ping","t":-1}"#, #"{"type":"hello","proto":-1,"rules":3,"name":"A","hero":"pip"}"#,
                   #"{"type":"welcome","name":"A","hero":"pip","map":"grove","width":0}"#,
                   #"{"type":"welcome","name":"A","hero":"pip","map":"grove","width":1e9}"#,
                   #"{"type":"welcome","name":"A","hero":"pip","map":"","width":351}"#,
                   #"{"type":"hello","proto":1,"rules":3,"name":"A","hero":"../etc"}"#]
        for s in bad { #expect(RaceMessage(json: json(s)) == nil, "\(s)") }
    }

    @Test func helloCarriesBothVersionsForTheSessionToCheck() {
        let m = RaceMessage(json: json(#"{"type":"hello","proto":2,"rules":9,"name":"Ana","hero":"moss"}"#))
        #expect(m == .hello(proto: 2, rules: 9, name: "Ana", hero: "moss"))
        #expect(RaceMessage.protocolVersion == 1)
    }

    @Test func namesAreCleaned() {
        #expect(RaceName.clean("  Ana\n") == "Ana")
        #expect(RaceName.clean("Ana\u{0007}\u{202E}lis") == "Analis")
        #expect(RaceName.clean("ABCDEFGHIJKLMNOP") == "ABCDEFGHIJKL")
        #expect(RaceName.clean("\n\t ") == "Player")
        #expect(RaceName.clean("🐉 Nova") == "🐉 Nova")
        let zalgo = String(repeating: "a\u{0301}\u{0302}\u{0303}\u{0304}\u{0305}\u{0306}", count: 12)
        #expect(RaceName.clean(zalgo).utf8.count <= RaceLimits.maxNameBytes)
        let decoded = RaceMessage(json: json(#"{"type":"hello","proto":1,"rules":3,"name":"  Ana\u0000Bee  ","hero":"moss"}"#))
        #expect(decoded == .hello(proto: 1, rules: 3, name: "AnaBee", hero: "moss"))
    }

    @Test func heroAndMapMustBeShortPlainWords() {
        #expect(RaceName.isToken("pip") && RaceName.isToken("iceCave2"))
        #expect(!RaceName.isToken("") && !RaceName.isToken("a b") && !RaceName.isToken("../x") && !RaceName.isToken("é"))
        #expect(!RaceName.isToken(String(repeating: "a", count: 33)))
    }

    @Test func ourOwnLongestMessageFitsInAFrame() {
        let name = RaceName.clean(String(repeating: "👩‍👩‍👧‍👦", count: 20))
        let m = RaceMessage.welcome(name: name, hero: String(repeating: "h", count: 32),
                                    map: String(repeating: "m", count: 32), width: 4999.123456789)
        #expect(RaceFrame.encode(m).count <= 4 + RaceFrame.maxBytes)
    }
}
