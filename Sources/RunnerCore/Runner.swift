import Foundation

/// The game rules. Every function is pure over `GameState`; events report what happened for the renderer and app.
public enum Runner {
    public static func newGame(world: World, seed: UInt64, best: Int) -> GameState {
        GameState(world: world, seed: seed, best: best)
    }

    /// Idle → running with an impulse; running → impulse; paused → running without one; crashed → nothing (the app
    /// starts a new game to retry).
    public static func flap(_ s: inout GameState, events: inout [GameEvent]) {
        switch s.phase {
        case .idle, .running:
            s.phase = .running
            s.pipVY = Params.flapVelocity
            events.append(.flapped)
        case .paused:
            s.phase = .running
        case .crashed:
            break
        }
    }

    public static func pause(_ s: inout GameState) {
        if s.phase == .running { s.phase = .paused }
        s.accumulator = 0
    }

    /// Which obsidian part Pip at height `y` touches, if Pip is inside the gate's columns.
    public static func partHit(_ g: Gate, y: Double) -> GatePart? {
        let r = Params.pipRadius
        if y - r < g.gapTop { return .top }
        if y + r > g.gapBottom { return .bottom }
        if g.isFork, abs(y - g.centre) < g.chunk / 2 + r { return .chunk }
        return nil
    }

    /// Runs as many fixed steps as `elapsed` (plus the carried remainder) allows, at most 8. A gap over 0.25 s (sleep,
    /// a stalled frame) pauses a running game instead of simulating it.
    public static func advance(_ s: inout GameState, elapsed: Double) -> [GameEvent] {
        var events: [GameEvent] = []
        guard elapsed <= Params.pauseGap else { pause(&s); return events }
        s.accumulator += max(0, elapsed)
        var n = Int((s.accumulator / Params.fixedStep + 1e-9).rounded(.down))
        if n > Params.maxStepsPerFrame {
            n = Params.maxStepsPerFrame
            s.accumulator = 0
        } else {
            s.accumulator = max(0, s.accumulator - Double(n) * Params.fixedStep)
        }
        for _ in 0..<n { step(&s, dt: Params.fixedStep, events: &events) }
        return events
    }

    /// The island was resized: same rules, new width. Pip sits at a fixed fraction of the width, so every gate (and the
    /// next spawn) moves by as much as Pip does: each gate keeps its distance from Pip, so passed gates stay behind and
    /// unscored ones stay ahead. Spawning resumes past the new right edge.
    public static func resize(_ s: inout GameState, world: World) {
        let shift = world.pipX - s.world.pipX
        s.world = world
        for i in s.gates.indices { s.gates[i].x += shift }
        s.nextGateX = max(s.nextGateX + shift, (s.gates.map(\.x).max() ?? 0) + Params.spacing, world.width + Params.spawnAhead)
    }

    /// One fixed step.
    public static func step(_ s: inout GameState, dt: Double, events: inout [GameEvent]) {
        s.time += dt
        for i in s.gates.indices {
            for part in Array(s.gates[i].melted.keys) { s.gates[i].melted[part]! += dt }
        }
        switch s.phase {
        case .idle:
            s.pipY = Params.idleY + sin(s.time * 3) * 6
            s.pipVY = cos(s.time * 3) * 40
            return
        case .paused, .crashed:
            return
        case .running:
            break
        }

        s.effects.tick(dt)
        s.pipVY = min(Params.maxFall, s.pipVY + Params.gravity * s.effects.gravityScale * dt)
        s.pipY += s.pipVY * dt
        if s.effects.hiccups > 0, s.rng.unit() < dt * Params.hiccupRate {
            s.pipVY = Params.flapVelocity * Params.hiccupStrength
            events.append(.hiccup)
        }

        let dx = s.speed * dt
        s.distance += dx
        s.nextGateX -= dx
        for i in s.gates.indices { s.gates[i].x -= dx }
        s.gates.removeAll { $0.x < Params.despawnX }
        while s.nextGateX < s.world.width + Params.spawnAhead { spawn(&s) }

        if !resolveGates(&s, events: &events) { return }

        if s.pipY - Params.pipRadius < 0 || s.pipY + Params.pipRadius > Params.ground { crash(&s, events: &events) }
    }

    /// Passing, pickups and obsidian contact. Returns false when the run crashed.
    static func resolveGates(_ s: inout GameState, events: inout [GameEvent]) -> Bool {
        let px = s.world.pipX, r = Params.pipRadius
        for i in s.gates.indices {
            if !s.gates[i].passed, s.gates[i].x + Params.gateWidth < px - r {
                s.gates[i].passed = true
                s.score += 1
                s.speed = min(Params.speedMax, s.speed + Params.speedPerGate)
                events.append(.gatePassed(score: s.score))
                if s.score % Params.milestoneEvery == 0 { events.append(.milestone(score: s.score)) }
            }
            collectPickups(&s, gate: i, events: &events)
            let g = s.gates[i]
            let inColumns = px + r > g.x && px - r < g.x + Params.gateWidth
            guard inColumns, let part = partHit(g, y: s.pipY), g.melted[part] == nil else { continue }
            if s.effects.emberCharge {
                s.effects.emberCharge = false
                s.gates[i].melted[part] = 0
                events.append(.melted(gateID: g.id, part: part))
            } else {
                crash(&s, events: &events)
                return false
            }
        }
        return true
    }

    /// Takes every untaken pickup Pip touches (within `pipRadius + pickupReach`), applying its effect once.
    static func collectPickups(_ s: inout GameState, gate i: Int, events: inout [GameEvent]) {
        let px = s.world.pipX
        let reach = Params.pipRadius + Params.pickupReach
        for j in s.gates[i].items.indices where !s.gates[i].items[j].taken {
            let item = s.gates[i].items[j]
            let dx = s.gates[i].itemX - px, dy = s.gates[i].itemY(item.side) - s.pipY
            guard dx * dx + dy * dy < reach * reach else { continue }
            s.gates[i].items[j].taken = true
            if item.pickup == .egg { s.score += Params.eggPoints }
            s.effects.apply(item.pickup)
            events.append(.picked(item.pickup))
        }
    }

    static func spawn(_ s: inout GameState) {
        let g = Spawner.makeGate(id: s.spawned, index: s.spawned, x: s.nextGateX, lastCentre: s.lastCentre,
                                 speed: s.speed, rng: &s.rng)
        s.gates.append(g)
        s.lastCentre = g.centre
        s.spawned += 1
        s.nextGateX += Params.spacing
    }

    static func crash(_ s: inout GameState, events: inout [GameEvent]) {
        s.phase = .crashed
        if s.score > s.best {
            s.best = s.score
            s.newBest = true
            events.append(.newBest(score: s.score))
        }
        events.append(.crashed(score: s.score))
    }
}
