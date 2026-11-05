# Upstream sources and reuse boundary

## Imported dependency

- Project: [chun92/card-framework](https://github.com/chun92/card-framework)
- Pinned commit: `a74b713863adb27a22965a8e6ed039d0c4016791`
- Imported path: upstream `addons/card-framework/`, copied to the same local path.
- License: MIT, copyright 2025 Hyunjoon Park; retained verbatim at `addons/card-framework/LICENSE`.
- Source scripts and scenes are unchanged. The upstream source archive excludes its examples/screenshots; they are not needed by the addon.
- Local integration lives in `ui/`. It supplies an explicit owning manager, disables unused drop-zone layout synchronization, and balances upstream static hover counters when a displayed hand is replaced.

## Design and gameplay references

- [db0/godot-card-game-framework](https://github.com/db0/godot-card-game-framework), reviewed at `f3ca9afd9705ff895839253fad208360d2f45146`: reference for interactions and effect-engine tradeoffs. **No code or assets imported.** Its published license is AGPL-3.0 with a Steamworks addendum.
- [blmz/GODOT-DouDiZhu](https://github.com/blmz/GODOT-DouDiZhu), reviewed at `58e8daa59efb38a4afa1d6de2da5752469f5a019`: first-game workflow reference. **No code, artwork, sound, scenes, or fonts imported.** No license file was supplied in the reviewed repository snapshot.

DouDiZhu rules, the session/replay layer, presentation adapter, and tests in this repository are original implementations. The M0 card faces use Godot drawing and the engine's built-in font.

## External action oracle

- [kwai/DouZero](https://github.com/kwai/DouZero), commit `718a5c920bf3361e34178a38f3b80458e176b351`, Apache-2.0: used outside the shipped runtime to generate numeric legal-action fixtures.
- `tests/fixtures/douzero_actions.json` records the upstream commit and SHA-256 hashes of `douzero/env/utils.py` and `move_generator.py`, along with 10 synthetic hands and 935 generated rank actions. No upstream Python source, model weights, or training data is bundled.
- `scripts/update_douzero_oracle.py` verifies the two pinned source hashes and regenerates the fixture from an explicitly supplied checkout/archive. Ordinary checks use the committed fixture and do not download or install DouZero.
- The six expected profile exclusions are recorded explicitly, rather than hidden by filtering upstream results through this project's classifier. See `docs/DOUZERO_ACTIONS.md`.
