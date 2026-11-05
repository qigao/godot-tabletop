# Godot Tabletop

A Godot 4 platform for card and board games. The first game is **DouDiZhu**.

面向多种棋牌玩法的 Godot 4 项目。首个实现是斗地主：规则、对局状态、命令与回放独立于界面，卡牌交互采用 MIT 许可的 Card Framework。

## Current: offline DouDiZhu with legal-play browsing

- Godot **4.6-stable**, standard GDScript build, Compatibility renderer.
- Local three-seat hotseat table with bidding, card selection, play, pass, and score display.
- Fourteen combination types, including airplanes with wings, four-with-two, bombs, and rocket.
- Bidding 0/1/2/3, automatic redeal after three passes, landlord bottom cards, trick reset after two passes.
- Bomb/rocket multipliers, spring/reverse spring, and zero-sum landlord/farmer scoring.
- Independent sessions, revision-checked commands, private player observations, and deterministic JSON replay.
- Complete rank-distinct legal actions with stable IDs and canonical owned-card representatives; shared action dispatch also works for the board-game fixture.
- **Next legal play** cycles through available plays without advancing the match. Selected responses that cannot beat the previous play are disabled.
- DouZero action-rank encoding/decoding checked against 935 outputs of a pinned upstream generator, with six explicit profile exclusions in those fixtures.
- Real use of the pinned `chun92/card-framework` addon for cards, hand layout, and hover/movement animation.

This is an offline prototype. Online rooms, remote DouZero inference, touch interaction acceptance, native/web export acceptance, and a playable board-game module are tracked in [the roadmap](docs/ROADMAP.md). The board-game fixture tests the common session contract; it is not a second shipped game.

## Run

Open `project.godot` with Godot 4.6-stable and press F6 on `ui/tabletop_app.tscn`, or F5.

1. Inspect the active seat's hand and bid 1/2/3, or choose **No bid**.
2. Click one or more cards, then **Play selected**. **Pass** is available when following a play.
   **Next legal play** cycles through the legal plays for this turn; it does not play automatically.
3. The hand switches to the highlighted seat. This is local hotseat: pass the device between players.
4. **Save replay** writes `user://last-replay.json`; **New match** restarts with the selected seed.

`S/H/C/D` mean spades/hearts/clubs/diamonds. `SJ/BJ` are the small/big jokers. Card faces are drawn by this project; no external game artwork is required.

## Check

```sh
python scripts/check.py /absolute/path/to/Godot
```

The runner imports the project, runs rules/replay tests, and instantiates the actual addon-backed UI. It rejects Godot script errors even when Godot returns exit status zero. GitHub Actions runs the same checks on Linux, Windows, and macOS; official engine archives are pinned and downloaded with `curl`, with no Mono installation.

The original rules suite includes all combination types and invalid boundaries, command rejection atomicity, bidding, pass reset, hidden information, scoring, two-session isolation, a board-state fixture, and **32 complete seeded single/pass matches**. The legal-action suite adds bounded exhaustive physical-subset comparisons, **935 pinned DouZero action outputs**, and **96 complete seeded mixed-combination matches** that actually play all 14 kinds. All complete matches undergo JSON serialization and replay. These drivers are acceptance tools, not production AI or evidence of trained-agent strength.

## Structure

| Path | Responsibility |
| --- | --- |
| `core/` | Game contract, independent match authority, revision checks, replay, catalog |
| `games/doudizhu/` | Card IDs, rule profile, pattern comparison, round state, scoring |
| `ui/` | Godot presentation and adapter to Card Framework |
| `addons/card-framework/` | Pinned upstream MIT addon |
| `tests/` | Rule acceptance, replay, board-contract fixture, actual scene smoke test |

Read [architecture](docs/ARCHITECTURE.md), [the exact DouDiZhu profile](docs/DOUDIZHU.md), [DouZero action mapping and differences](docs/DOUZERO_ACTIONS.md), and [upstream provenance](THIRD_PARTY.md).

## License

MIT for this project's original code. The vendored addon retains Hyunjoon Park's MIT notice. See [LICENSE](LICENSE) and [THIRD_PARTY.md](THIRD_PARTY.md).
