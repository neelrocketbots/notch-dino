/// The other player's run, rebuilt from their seed, the race world and their flap steps. `advance(to:)` gives the
/// exact state at that step from the flaps known so far. Between flaps it glides; no flap is guessed. A flap that
/// arrives after the ghost has passed its step is inserted and the run replays from step 0. A 2-minute race is about
/// 14,400 steps, so a replay is cheap.
public struct Ghost: Equatable, Sendable {
    public let seed: UInt64
    public let world: World
    public private(set) var flaps: [Int] = []
    public private(set) var state: GameState
    /// Index of the first flap not yet applied.
    private var next = 0

    public init(seed: UInt64, world: World) {
        self.seed = seed
        self.world = world
        state = Ghost.start(seed: seed, world: world)
    }

    /// The run at "go": what every Mac's game is when its countdown ends. `best` is out of reach, so a ghost (or a
    /// race game) never reports a new best.
    public static func start(seed: UInt64, world: World) -> GameState {
        var s = Runner.newGame(world: world, seed: seed, best: Int.max)
        Runner.go(&s)
        return s
    }

    /// Adds a flap at `step`. Steps must increase; one that does not is ignored (the session has already checked).
    public mutating func add(flap step: Int) {
        guard step >= 0, step > (flaps.last ?? -1) else { return }
        flaps.append(step)
        guard step < state.step else { return }
        let target = state.step
        state = Ghost.start(seed: seed, world: world)
        next = 0
        advance(to: target)
    }

    /// Runs fixed steps until `state.step == target`. A crashed run's clock keeps counting, so this always arrives.
    @discardableResult
    public mutating func advance(to target: Int) -> [GameEvent] {
        var events: [GameEvent] = []
        while state.step < target, state.phase == .running || state.phase == .crashed {
            while next < flaps.count, flaps[next] <= state.step {
                if flaps[next] == state.step { Runner.flap(&state, events: &events) }
                next += 1
            }
            Runner.step(&state, dt: Params.fixedStep, events: &events)
        }
        return events
    }
}
