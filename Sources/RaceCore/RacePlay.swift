import RunnerCore

/// Applies a session's game commands to the local run, the same way on every Mac and in tests.
public enum RacePlay {
    /// Runs `startGame`, `freeze` and `resume` on `game`; returns the rest (`send`, `notice`, `close`) in order for
    /// the app. A race run's best is out of reach, so it never reports a new best and never touches the solo best.
    public static func apply(_ commands: [RaceCommand], to game: inout GameState, world: World) -> [RaceCommand] {
        var rest: [RaceCommand] = []
        for command in commands {
            switch command {
            case .startGame(let seed, let steps):
                game = Runner.newGame(world: world, seed: seed, best: Int.max)
                Runner.startCountdown(&game, steps: steps)
            case .freeze(let atStep):
                Runner.schedulePause(&game, atStep: atStep)
            case .resume(let steps):
                Runner.startCountdown(&game, steps: steps)
            case .send, .notice, .close:
                rest.append(command)
            }
        }
        return rest
    }
}
