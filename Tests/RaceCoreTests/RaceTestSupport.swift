import Foundation
@testable import RaceCore
import RunnerCore

let neel = RacePlayer(name: "Neel", hero: "pip")
let ana = RacePlayer(name: "Ana", hero: "moss")
let raceWorld = World(width: 351)

func sent(_ commands: [RaceCommand]) -> [RaceMessage] {
    commands.compactMap { if case .send(let m) = $0 { m } else { nil } }
}

func startSeed(_ commands: [RaceCommand]) -> UInt64? {
    for c in commands { if case .startGame(let seed, _) = c { return seed } }
    return nil
}

/// Host and guest through the handshake, at time 0.
func readyPair() -> (host: RaceSession, guest: RaceSession) {
    var host = RaceSession(hostingAs: neel, map: "glacier", world: raceWorld, seed: 9)
    var guest = RaceSession(joiningAs: ana, seed: 4)
    _ = host.handle(.connected, now: 0)
    let hello = sent(guest.handle(.connected, now: 0))
    let welcome = sent(host.handle(.received(hello[0]), now: 0))
    _ = guest.handle(.received(welcome[0]), now: 0)
    return (host, guest)
}

/// Host and guest past the countdown, racing on the returned seed, at time 0 and step 0.
func racingPair() -> (host: RaceSession, guest: RaceSession, seed: UInt64) {
    var (host, guest) = readyPair()
    let start = host.handle(.startPressed, now: 0)
    _ = guest.handle(.received(sent(start)[0]), now: 0)
    _ = host.handle(.tick(step: 0, phase: .running), now: 0)
    _ = guest.handle(.tick(step: 0, phase: .running), now: 0)
    return (host, guest, startSeed(start)!)
}

/// A run that flaps whenever Pip sinks below the next opening until step `flyUntil`, then falls. Its flaps and
/// crash are what that player's Mac would send.
func pilotRun(seed: UInt64, flyUntil: Int) -> (flaps: [Int], crash: RaceScore) {
    var s = Ghost.start(seed: seed, world: raceWorld)
    var flaps: [Int] = []
    var ev: [GameEvent] = []
    while s.phase == .running {
        if s.step < flyUntil {
            let next = s.gates.first { $0.x + Params.gateWidth > s.world.pipX - Params.pipRadius }
            let target = next.map { $0.isFork ? $0.itemY(.upper) : $0.centre } ?? Params.idleY
            if s.pipY > target + 4, s.pipVY > -40 {
                Runner.flap(&s, events: &ev)
                flaps.append(s.step)
            }
        }
        Runner.step(&s, dt: Params.fixedStep, events: &ev)
    }
    return (flaps, RaceScore(step: s.crashStep!, score: s.score))
}

/// Both fall without flapping and report it: a tie.
func bothFall(_ host: inout RaceSession, _ guest: inout RaceSession, seed: UInt64) {
    let fall = pilotRun(seed: seed, flyUntil: 0).crash
    _ = host.handle(.crashed(step: fall.step, score: fall.score), now: 0)
    _ = guest.handle(.crashed(step: fall.step, score: fall.score), now: 0)
    _ = host.handle(.received(.crashed(step: fall.step, score: fall.score)), now: 0)
    _ = guest.handle(.received(.crashed(step: fall.step, score: fall.score)), now: 0)
}
