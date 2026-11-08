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
| Space, ↑ or click | Flap (also starts a run, and retries after a crash) |
| Esc | Pause and fold. Switching to another app does the same |
| ⌘Q | Quit, while the game is open |

You score a point for every gate you pass. Every sixth gate is a **fork**: a floating chunk of obsidian splits the
gap, and each of the two openings holds something. Pick your opening.

| Power-up | Effect |
| --- | --- |
| Ember | Melts the next piece of obsidian you hit instead of ending the run. You can hold one at a time. It doesn't protect you from the ceiling or the ground. |
| Golden egg | +5 points. |
| Updraft | Lighter gravity for 5 s. |

| Power-down | Effect |
| --- | --- |
| Ash cloud | Smoke hides the field ahead for 4 s. |
| Stone scale | Heavier gravity for 5 s. |
| Hiccups | Random hops for 4 s. |

You can drag the island off the notch to float it anywhere, and resize it while the game is paused.

## Heroes and maps

Pick who flies and where from the **Hero** and **Map** menus under the flame icon in the menu bar. Your choice is
remembered. It's art only: the rules are the same everywhere.

<p align="center">
  <img src="assets/pip-volcano.png" width="270" alt="Pip, the red dragon, over Ember Peaks: a red night sky with volcanoes and cycad silhouettes">
  &nbsp;
  <img src="assets/moss-glacier.png" width="270" alt="Moss, the green dragon, over Glacier: a blue night sky with snow-capped peaks and pines">
  &nbsp;
  <img src="assets/nova-grove.png" width="270" alt="Nova, the violet dragon, over Night Grove: dark green hills with mushrooms and fireflies">
</p>
<p align="center"><sub>Pip in Ember Peaks · Moss in Glacier · Nova in Night Grove</sub></p>

| Hero | Look |
| --- | --- |
| Pip | The red baby dragon. |
| Moss | Green, with a leaf crest. |
| Nova | Violet, with gold horns, starry wings and a star tail. |

| Map | Obstacles |
| --- | --- |
| Ember Peaks | Obsidian among volcanoes and cycads. |
| Glacier | Ice crystals among snow-capped peaks and pines. |
| Night Grove | Thornwood trunks and mossy boulders among hills, mushrooms and fireflies. |

## Trust

- **No network.** No analytics, no accounts, no ads, nothing sent anywhere.
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
