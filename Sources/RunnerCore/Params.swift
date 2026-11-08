/// Every game rule number, in world units (the world is 200 units tall) and seconds.
public enum Params {
    /// The version of these rules. The v1 rules are 1; every change to the rules (a number here, an effect, the odds)
    /// bumps it, so two games can check they play by the same rules.
    public static let rulesVersion = 2
    public static let worldHeight = 200.0
    public static let ground = 188.0                 // top of the ground strip
    public static let gravity = 900.0
    public static let flapVelocity = -235.0          // y grows downward
    public static let maxFall = 330.0
    public static let speedStart = 140.0, speedPerGate = 2.0, speedMax = 260.0
    public static let spacing = 170.0                // between gate left edges
    public static let gapStart = 0.45, gapMin = 0.32 // fractions of worldHeight
    public static let gapRampGates = 40
    public static let gateWidth = 15.0               // 18 pt at the default 1.2 pt/unit
    public static let pipXFraction = 0.25
    public static let pipRadius = 9.0
    /// Space kept between a gap and the ceiling / ground: small, so openings use the whole field height.
    public static let topMargin = 10.0, groundMargin = 8.0
    public static let climbRate = 120.0, maxShiftCap = 60.0
    public static let forkEvery = 6
    public static let forkGap = 0.75, chunk = 0.12   // fractions of worldHeight
    public static let pickupReach = 6.0
    public static let fixedStep = 1.0 / 120.0
    public static let maxStepsPerFrame = 8
    public static let pauseGap = 0.25
    public static let milestoneEvery = 10
    public static let eggPoints = 5
    public static let updraftGravity = 0.6, stoneGravity = 1.35
    public static let updraftTime = 5.0, stoneTime = 5.0, hiccupTime = 4.0, ashTime = 4.0
    public static let hiccupRate = 1.5, hiccupStrength = 0.55
    public static let tinyScale = 0.7, bloatScale = 1.3, tinyTime = 5.0, bloatTime = 5.0
    public static let rushSpeed = 1.3, rushTime = 4.0
    /// A feather bounce sets Pip's edge `featherInset` units inside the field, moving away at `flapVelocity × featherBounce`.
    public static let featherBounce = 0.8, featherInset = 2.0
    public static let idleY = 96.0
    public static let spawnAhead = 20.0
    public static let despawnX = -45.0
}
