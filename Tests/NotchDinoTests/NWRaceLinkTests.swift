import Foundation
import Network
import RaceCore
import Testing
@testable import NotchDinoApp

@Suite struct NWRaceLinkTests {
    @Test func theServiceTypeAndPeerToPeer() {
        #expect(RaceBonjour.type == "_notchdino._tcp")
        #expect(RaceBonjour.parameters().includePeerToPeer)
    }

    @Test func aTXTRecordBecomesAHost() {
        let txt = RaceBonjour.txt(name: "Ana", hero: "moss", map: "glacier")
        #expect(txt["proto"] == "\(RaceMessage.protocolVersion)")
        #expect(RaceBonjour.host(id: "x", txt: txt) == RaceHost(id: "x", name: "Ana", hero: "moss", map: "glacier"))
    }

    @Test func badTXTRecordsAreSkippedAndNamesCleaned() {
        #expect(RaceBonjour.host(id: "x", txt: ["name": "Ana", "hero": "moss"]) == nil)
        #expect(RaceBonjour.host(id: "x", txt: ["name": "Ana", "hero": "../x", "map": "grove"]) == nil)
        #expect(RaceBonjour.host(id: "x", txt: ["hero": "moss", "map": "grove"]) == nil)
        let long = RaceBonjour.host(id: "x", txt: ["name": "\u{202E}AnaAnaAnaAnaAna\n", "hero": "moss", "map": "grove"])
        #expect(long?.name == "AnaAnaAnaAna")
    }

    @Test func localNetworkDenialIsRecognised() {
        #expect(RaceBonjour.isDenied(.dns(-65570)))   // kDNSServiceErr_PolicyDenied
        #expect(!RaceBonjour.isDenied(.dns(-65537)))
        #expect(!RaceBonjour.isDenied(.posix(.ECONNREFUSED)))
    }

    // Ruling 2: a host keeps hosting through a transient wait (no network yet, Wi-Fi switching); only a Local Network
    // denial or a real failure ends it.
    @Test func aListenerWaitingWithoutADenialKeepsHosting() {
        #expect(RaceBonjour.listenerFailure(.waiting(.posix(.ENETDOWN))) == nil)
        #expect(RaceBonjour.listenerFailure(.waiting(.dns(-65537))) == nil)
        #expect(RaceBonjour.listenerFailure(.waiting(.dns(-65570))) == .denied)
        #expect(RaceBonjour.listenerFailure(.failed(.dns(-65570))) == .denied)
        #expect(RaceBonjour.listenerFailure(.failed(.posix(.EADDRINUSE))) == .lost)
        for state: NWListener.State in [.setup, .ready, .cancelled] { #expect(RaceBonjour.listenerFailure(state) == nil) }
    }
}
