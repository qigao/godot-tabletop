# Local game engine integration

The local client supports deterministic, turn-based engines through an adapter. Engine-specific implementation stays under `games/<id>/`; UI rendering stays in a registered view. No card/board choice is hardcoded in the host.

## Rules adapter

Implement `TabletopRules` and give the profile a stable identity/revision:

| Method | Contract |
| --- | --- |
| `game_id()` | Same identity as the module descriptor |
| `rules_revision()` | Exact profile revision; changed semantics require a new revision |
| `initial_state(seed)` | Deterministic fresh value state; seed is an unsigned 32-bit value |
| `active_seat(state)` | Valid seat in `0 .. seat_count - 1`, including the final frame |
| `apply(state, seat, command)` | New state and events on success; error without mutating input on rejection |
| `observe(state, seat)` | Detached, seat-visible value data |
| `legal_actions(state, seat)` | Available `{id, command}` entries; empty when the seat cannot act |

Commands and state belong to that engine. A card engine can use `play/cards`, a chess engine `move/from/to/promotion`, and a placement game `place/cell`. The client only forwards dictionary commands. It does not impose a shared game-state schema or a card-based inheritance tree.

Wrap an external engine here by translating its positions, legal moves and transitions into this contract. Each local table must own independent state. The adapter must replay from seed plus commands, preserve observation isolation, and keep engine/UI objects out of replay JSON. This milestone ships GDScript engines; no native or remote engine ABI is claimed.

## View adapter and registration

1. Create `ui/views/<game>_view.tscn` with a script extending `TabletopGameView`.
2. Implement `render(observation, legal_actions)` and `deactivate()`.
3. In controls, call `request_command(command)`. The base emits the last presented token; do not keep or mutate a live session in the view.
4. Honor `blocked` in the controls and stop input/animations in `deactivate()`.
5. Create `games/<id>/module.tres` with `id`, `title`, `kind`, `seat_count`, `rules_script`, and `view_scene`.
6. Add that descriptor to `TabletopCatalog.MODULES`. The generic picker, table tabs, toolbar and replay import then work through the module.

See `games/gomoku/module.tres` and `ui/views/gomoku_view.gd` for a small complete integration. DouDiZhu provides a larger card example. The fixture under `tests/fixtures/` is only an authority-contract test, not a product module.

Shared widgets are optional:

- `TabletopCardFactory` uses string keys and `{title, symbol, ink}` metadata; `selection_hand.gd` emits selected keys without changing a game state.
- `TabletopCardManager` owns its factory and input scope explicitly. Give every card view its own manager; do not call the upstream root-scene lookup.
- `TabletopBoardCanvas` exposes rows/columns, piece fill/outline/text, focus and highlight data, plus `cell_activated(cell)`. Interpret that cell in the view: selecting a piece and then a destination can generate one engine command.
- Games requiring square tiles, drag paths, irregular boards or richer pieces may provide their own Control inside the same view contract.

## Client behavior provided to every game

A table owns its seed, session, pause state, full timeline, cursor and UI token. The workspace owns distinct table IDs and the active table. Common controls create/switch/restart/close, pause, undo/redo/seek, save and load. A new command from the middle of history creates a branch. A rejected command never discards the redo tail.

Loading validates the complete JSON archive first and attaches a new table only after success. Switching, seeking or resetting invalidates commands queued against the previous displayed frame. Closing and reopening does not reuse an ID.

## Acceptance for an added game

Exercise real legal/illegal transitions, rejection atomicity, terminal outcomes, observation isolation, legal-action IDs, full JSON replay, independent interleaved matches, common history controls and the mounted view. Include rule-specific boundaries rather than mirroring the implementation.

The current suites cover complete games and a full 225-move Gomoku draw, two engine types in one workspace, two simultaneous card views, real Godot mouse/touch/key event paths, stale queued input, save/load, resize and teardown. Packaging reruns the actual scene suite from the generated PCK. Linux OpenGL captures verify the actual scenes at desktop and compact sizes.

Physical mouse/touch devices, DPI/OS behavior and signed/mobile/web distribution require their own acceptance in [#2](https://github.com/qigao/godot-tabletop/issues/2). For manual acceptance, create both games, play legal and rejected moves, review/branch/save/load, switch a hovered card hand to the board, resize, pause/resume, close all tables and create again. Touch must activate toolbar controls and each game move exactly once. Automated injection does not close that physical-device task.
