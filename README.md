# Notch Dino

A tiny, free macOS game that opens out of the MacBook notch.

<p align="center">
  <img src="assets/run.png" width="560" alt="Pip, a small red dragon, flying across a dark volcanic night sky towards a pair of obsidian shards, with the best score and current score in the notch band above">
</p>

Click the notch, press **⌃⌥Space**, or choose **Play** from the flame icon in the menu bar, then steer Pip, a baby dragon learning to fly, through obsidian gates with
**Space**. Press **Esc** to fold the game back into the notch. While it's folded, it does nothing at all.

<p align="center">
  <img src="assets/idle.png" width="270" alt="The island just opened: Pip hovers in place beside a 'space to flap' prompt">
  &nbsp;
  <img src="assets/crash.png" width="270" alt="A crashed run: a glass card shows the score and 'space to retry'">
</p>

## How to play

| Key | Action |
| --- | --- |
| ⌃⌥Space | Open or fold the game, from any app |
| Space, ↑ or click | Flap (also starts a run after a 3-2-1, and retries after a crash) |
| P | Pause in place. P or Space resumes after a 3-2-1 |
| R | Race someone on your local network (on the idle screen) |
| Esc | Pause and fold. Switching to another app does the same |
| ⌘Q | Quit, while the game is open |

You score a point for every gate you pass. Every sixth gate is a **fork**: a floating chunk of obsidian splits the
gap, and each of the two openings holds something. Pick your opening.

| Power-up | Effect |
| --- | --- |
| Ember | Melts the next piece of obsidian you hit instead of ending the run. You can hold one at a time. It doesn't protect you from the ceiling or the ground. |
| Golden egg | +5 points. |
| Updraft | Lighter gravity for 5 s. |
| Feather | Bounces you off the ceiling or the ground once instead of ending the run. You can hold one at a time. |
| Tiny | You shrink to 70% for 5 s, so gaps are easier. |

| Power-down | Effect |
| --- | --- |
| Ash cloud | Smoke hides the field ahead for 4 s. |
| Stone scale | Heavier gravity for 5 s. |
| Hiccups | Random hops for 4 s. |
| Rush | The world speeds up by 30% for 4 s. |
| Bloat | You puff up to 130% for 5 s. |

Tiny and Bloat cancel each other out, and so do Updraft and Stone scale.

You can drag the island off the notch to float it anywhere.

## Heroes and maps

Pick who flies and where from the **Hero** and **Map** menus under the flame icon in the menu bar. Your choice is
remembered. It's art only: the rules are the same everywhere.

| | |
| :-: | :-: |
| <img src="assets/pip-volcano.png" width="380" alt="Pip, the red dragon, over Ember Peaks: volcanoes and cycads under a red night sky"><br><sub>Pip in Ember Peaks</sub> | <img src="assets/moss-glacier.png" width="380" alt="Moss, the green dragon, over Glacier: snow-capped peaks and pines under a blue night sky"><br><sub>Moss in Glacier</sub> |
| <img src="assets/nova-grove.png" width="380" alt="Nova, the violet dragon, over Night Grove: dark hills, mushrooms and fireflies"><br><sub>Nova in Night Grove</sub> | <img src="assets/coral-dunes.png" width="380" alt="Coral, the pink dragon, over Dune Sea: dunes and cacti under a sunset sky"><br><sub>Coral in Dune Sea</sub> |
| <img src="assets/frost-skyisles.png" width="380" alt="Frost, the pale blue dragon, over Sky Isles: cloud banks and floating islands"><br><sub>Frost in Sky Isles</sub> | <img src="assets/sable-bamboo.png" width="380" alt="Sable, the charcoal dragon, over Bamboo Vale: misty hills, bamboo and lanterns"><br><sub>Sable in Bamboo Vale</sub> |
| <img src="assets/saffron-crystal.png" width="380" alt="Saffron, the golden dragon, in Crystal Caves: stalactites and glowing amethyst"><br><sub>Saffron in Crystal Caves</sub> | <img src="assets/tide-storm.png" width="380" alt="Tide, the teal dragon, over Storm Coast: rain, sea cliffs and a lighthouse beam"><br><sub>Tide in Storm Coast</sub> |
| <img src="assets/rust-autumn.png" width="380" alt="Rust, the copper dragon, over Autumn Woods: orange canopy and birches at dusk"><br><sub>Rust in Autumn Woods</sub> | <img src="assets/blossom-ruins.png" width="380" alt="Blossom, the lilac dragon, over Lost Ruins: jungle temple silhouettes at night"><br><sub>Blossom in Lost Ruins</sub> |

| Hero | Look |
| --- | --- |
| Pip | The red baby dragon. |
| Moss | Green, with a leaf crest. |
| Nova | Violet, with gold horns, starry wings and a star tail. |
| Coral | Pink, with frilled fin ears. |
| Frost | Pale blue-white, with crystal horns. |
| Sable | Charcoal, with glowing ember freckles. |
| Saffron | Golden yellow, with a round belly and stubby wings. |
| Tide | Teal, with webbed, fin-edged wings. |
| Rust | Copper, with plated back scales. |
| Blossom | Lilac, with petal-shaped wings. |

| Map | Obstacles |
| --- | --- |
| Ember Peaks | Obsidian among volcanoes and cycads. |
| Glacier | Ice crystals among snow-capped peaks and pines. |
| Night Grove | Thornwood trunks and mossy boulders among hills, mushrooms and fireflies. |
| Dune Sea | Sandstone pillars among sunset dunes and cacti. |
| Sky Isles | Rock spires with dangling roots, above the clouds. |
| Bamboo Vale | Bamboo bundles among misty hills and lanterns. |
| Crystal Caves | Amethyst clusters under a stalactite ceiling. |
| Storm Coast | Basalt columns in the rain, by a lighthouse. |
| Autumn Woods | Birch trunks under an orange canopy. |
| Lost Ruins | Vine-wrapped stone columns among jungle temples. |

## Racing

Two Macs on the same network can race the same course at the same time. Press **R** on the idle screen, or choose
**Race Nearby…** from the flame icon, then host a race or join one from the list. You see the other player as a
translucent ghost of their hero, on the host's map. The race runs until both dragons have crashed: the higher score
wins, golden eggs included, and equal scores tie.

| Key | In a race |
| --- | --- |
| Space | Flap. The host starts the race; on the result card, Space asks for a rematch |
| P | Pause both players. Only the player who paused can resume. 3 pauses each, 60 s at most |
| Esc | Fold while flying (this pauses the race). On a race panel, leave |
| N | Change your player name in the lobby (or Player Name… in the menu bar) |

Leaving, quitting or a lost connection ends the match for both players. Race scores never touch your solo best.
Racing needs the app bundle (see Build): macOS only asks for Local Network access for an app.

## Trust

- **No internet.** Racing talks only to one other Mac on your local network, and only while a race is open.
  No analytics, no accounts, no ads. Nothing listens or looks for other Macs until you press R or choose
  Race Nearby…, and it all stops when you leave the race.
- **No special permissions.** The global hot-key is registered with Carbon's `RegisterEventHotKey`, so the app only
  ever hears ⌃⌥Space. It doesn't ask for Accessibility or Input Monitoring access, and keys you press while the game
  is folded go straight to the app you're using.
- **Idle means idle.** While folded, the scene is paused. Measured over 30 s folded: 0.0% CPU, 0 wake-ups,
  about 36 MB of memory.
- **Open source.** Everything the app does is in `Sources/`.

## Build

Requires macOS 26 or later and Swift 6.2. Built on [NotchKit](https://github.com/neelrocketbots/notchkit).

    swift run NotchDino      # play
    swift test               # game rules and app logic

## License

MIT — see [LICENSE](LICENSE).
