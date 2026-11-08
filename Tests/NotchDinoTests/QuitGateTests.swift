import Foundation
import Testing
@testable import NotchDinoApp

/// A clock the test moves by hand: `after` only records, `advance` fires what is due.
@MainActor final class ManualTimer {
    var now = 0.0
    private var due: [(at: Double, run: @MainActor () -> Void)] = []
    func after(_ seconds: Double, _ run: @escaping @MainActor () -> Void) { due.append((now + seconds, run)) }
    func advance(_ seconds: Double) {
        now += seconds
        let ready = due.filter { $0.at <= now + 1e-9 }
        due.removeAll { $0.at <= now + 1e-9 }
        for d in ready { d.run() }
    }
}

@MainActor final class Replies { var values: [Bool] = [] }

@Suite struct QuitGateTests {
    @MainActor @Test func withNoRaceQuittingIsImmediate() {
        let timer = ManualTimer(), replies = Replies()
        var timers = 0
        let d = QuitGate.begin(sendBye: { _ in false },
                               after: { s, r in timers += 1; timer.after(s, r) }, reply: { replies.values.append($0) })
        #expect(d == .now && timers == 0)
        timer.advance(1)
        #expect(replies.values.isEmpty)
    }

    @MainActor @Test func inARaceItWaitsForTheByeToGoOut() {
        let timer = ManualTimer(), replies = Replies()
        var sent: (@MainActor () -> Void)?
        let d = QuitGate.begin(sendBye: { sent = $0; return true },
                               after: timer.after, reply: { replies.values.append($0) })
        #expect(d == .later && replies.values.isEmpty)
        timer.advance(0.1)
        #expect(replies.values.isEmpty)
        sent?()
        #expect(replies.values == [true])
        timer.advance(1)
        sent?()
        #expect(replies.values == [true])
    }

    @MainActor @Test func aByeThatNeverGoesOutQuitsAfter300ms() {
        let timer = ManualTimer(), replies = Replies()
        var sent: (@MainActor () -> Void)?
        let d = QuitGate.begin(sendBye: { sent = $0; return true },
                               after: timer.after, reply: { replies.values.append($0) })
        #expect(d == .later)
        timer.advance(0.29)
        #expect(replies.values.isEmpty)
        timer.advance(0.01)
        #expect(replies.values == [true])
        sent?()
        #expect(replies.values == [true])
        #expect(QuitGate.timeout == 0.3)
    }
}
