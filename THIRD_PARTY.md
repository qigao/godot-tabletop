# Upstream sources and reuse boundary

## Bundled development runtime

- CI client bundles include the verified official standard Godot 4.6-stable executable, without modifying it.
- Godot's MIT notice and bundled third-party notices are copied verbatim from the `4.6-stable` source tag into `licenses/GODOT_LICENSE.txt` and `licenses/GODOT_COPYRIGHT.txt`. Both files accompany the runtime in each client bundle.
- These notices describe the official engine distribution; this repository does not vendor or modify the engine's source.

## Imported dependency

- Project: [chun92/card-framework](https://github.com/chun92/card-framework)
- Pinned commit: `a74b713863adb27a22965a8e6ed039d0c4016791`
- Imported path: upstream `addons/card-framework/`, copied to the same local path.
- License: MIT, copyright 2025 Hyunjoon Park; retained verbatim at `addons/card-framework/LICENSE`.
- Source scripts and scenes are unchanged. The upstream source archive excludes its examples/screenshots; they are not needed by the addon.
- Local integration lives in `ui/`. Each view owns an explicit manager, factory and input scope, without registering a manager in root-scene metadata. The adapter chooses hover ownership per view, disables unused drop-zone synchronization, and balances upstream static counters when a hand is replaced or removed. The shared factory/card/hand take generic keys and display metadata; game-specific bindings stay in presentation resources. Local adapters supply stable-slot input, gesture handling and composed hover/selection/motion; the pinned addon remains unchanged.

## Design and gameplay references

- [db0/godot-card-game-framework](https://github.com/db0/godot-card-game-framework), reviewed at `f3ca9afd9705ff895839253fad208360d2f45146`: reference for interactions and effect-engine tradeoffs. **No code or assets imported.** Its published license is AGPL-3.0 with a Steamworks addendum.
- [blmz/GODOT-DouDiZhu](https://github.com/blmz/GODOT-DouDiZhu), reviewed at `58e8daa59efb38a4afa1d6de2da5752469f5a019`: first-game workflow reference. **No code, artwork, sound, scenes, or fonts imported.** No license file was supplied in the reviewed repository snapshot.

DouDiZhu/Gomoku rules, the session/replay and local client layers, presentation adapters, and tests in this repository are original implementations. The M0 card faces use Godot drawing and the engine's built-in font.

## External action oracle

- [kwai/DouZero](https://github.com/kwai/DouZero), commit `718a5c920bf3361e34178a38f3b80458e176b351`, Apache-2.0: used outside the shipped runtime to generate numeric legal-action fixtures.
- `tests/fixtures/douzero_actions.json` records the upstream commit and SHA-256 hashes of `douzero/env/utils.py` and `move_generator.py`, along with 10 synthetic hands and 935 generated rank actions. No upstream Python source, model weights, or training data is bundled.
- `scripts/update_douzero_oracle.py` verifies the two pinned source hashes and regenerates the fixture from an explicitly supplied checkout/archive. Ordinary checks use the committed fixture and do not download or install DouZero.
- The six expected profile exclusions are recorded explicitly, rather than hidden by filtering upstream results through this project's classifier. See `docs/DOUZERO_ACTIONS.md`.

## Demonstration media

- The table, card-face, joker and stone SVGs are original code-native assets created for this repository. Card/deal/stone WAV effects and the looping background tracks are original synthesized audio.
- The example speech WAVs under `games/doudizhu/assets/voice/` were generated locally with eSpeak NG 1.51 using the phrases and command documented in that directory. They are replaceable demonstration speech, not recorded third-party game audio or final production narration. No synthesizer source, executable, voice data, model weights or external recording is bundled.
- Media is loaded from the configured game resources. Ordinary checks and client playback require no speech generation/download.

The interaction baseline was independently implemented after inspecting the pinned DouDiZhu reference scripts/scenes. No code/media was copied. The exact mapping, distinction between baseline and added sweep/drop modes, and device acceptance limits are documented in `docs/INTERACTION.md`.
