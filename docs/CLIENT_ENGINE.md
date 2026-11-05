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

## Two presentation families

Card tables and boards share the local session/workspace host. They have different configuration resources, renderers and interactions:

| Family | Configuration | Reused renderer | Current example |
| --- | --- | --- | --- |
| Card table | `TabletopCardTableLayout` | `ui/cards/card_table_view.tscn` | DouDiZhu |
| Placement board | `TabletopBoardLayout` | `ui/boards/placement_board_view.tscn` | Gomoku |

The host has no branches on these families or on individual games. Its module descriptor supplies `rules_script`, `view_scene`, and `presentation`. Both reference games use a family renderer, with no individual game view script.

This is a component template system, not automatic layout inference from rules. A developer supplies rules + layout/interaction configuration + media + one catalog entry. New interactions, such as chess piece selection followed by a destination, need an additional board component/view; the placement template does not claim that behavior.

## DouDiZhu: complete configured example

| File | Developer supplies |
| --- | --- |
| `games/doudizhu/rules.gd` and rule helpers | Deal, bidding, legal actions, comparisons, outcomes and scoring |
| `games/doudizhu/presentation.tres` | Seat order, observation bindings, phase labels, card-table sections and command controls |
| `games/doudizhu/media.tres` | 54 card definitions, selection equivalence, SVG artwork and event-to-audio mappings |
| `games/doudizhu/assets/` | Replaceable table/card/joker images and example speech recordings |
| `games/doudizhu/module.tres` | Rules + shared card scene + presentation descriptor |

Copy the resource structure for another compatible card game, provide its rules and observation bindings, and register the module in `TabletopCatalog.MODULES`. The game does not need its own UI script while it fits the current components. Rules never import or load the media/layout resources.

The card layout specifies `sections` (table, hand, actions, help), `seat_order`, card dimensions, hand/table heights, colors and observation text/hand bindings. Every action defines `id`, `label`, `when`, a command dictionary, `selection_field`, and `browse`. Fixed commands such as bids are enabled only when available in the rules' legal-action list. Selection commands copy the actual selected physical keys into the configured field. Browsing selects legal cards without submitting a move.

Rules may enumerate a canonical representative for equivalent cards. `selection_equivalence` names a metadata field used to compare selected and legal-action multisets; DouDiZhu uses its card rank `group`. Thus choosing a different owned suit of the same rank is allowed, and its actual physical ID reaches the rules validator. Configure `numeric_card_keys` explicitly; string keys are supported by the same renderer. The acceptance fixture uses different observation names and `{action: "discard", pieces: ["red-b"]}` commands to prove reuse beyond DouDiZhu.

## Value bindings

Bindings read detached observation/metadata values. They cannot change a session, call methods, evaluate source code, or decide legal moves. Missing paths and unknown operators are broken configuration and fail immediately.

| Operator | Form / purpose |
| --- | --- |
| `get` | `{"get": "observation.turn"}`: dictionary path |
| `at` | `{"at": [collection_binding, index_binding]}`: dynamic array/dictionary index |
| `text` | Convert a bound value to a string, including string asset keys |
| `format` | `{"format": ["Seat %d", argument_binding]}`: label formatting |
| `eq` | Compare two bound values |
| `empty` | Check an array/dictionary/string |
| `if` | `[condition, true_value, false_value]`; only the selected branch is read |
| `map` | `[collection, item_binding]`; exposes `item` in a local context |
| `join` | `[separator, collection]`: combine displayed values |

Plain values are literals, and arrays recursively bind their elements. Each operator dictionary contains exactly one operator. Context contains `observation` and `assets.cards`; seat labels add `seat` and `seat_number`, while the selection label adds `selection_count` and `legal_count`. Edit these exported Godot resources in the inspector or as text. The profile's observations remain game-owned; these bindings avoid putting formatting logic into rules.

## Media and live event cues

`TabletopMediaPack` holds optional table/card textures, per-card artwork, card metadata, piece definitions and audio cues. Card faces retain their rank/suit labels over the configured artwork. A board piece explicitly uses `disc` or `image` mode. Gomoku has separate stone-image mappings and its own placement-board resource.

Each `TabletopAudioCue` supplies an event type, optional exact field filters (including paths such as `pattern.kind`), an `AudioStream`, channel (`effect` or `voice`) and volume. The example binds bidding/pass/outcome speech, bomb/rocket speech and card/deal effects. Speech files are local synthesized demonstration recordings; replace them with licensed game recordings through media configuration. No runtime speech generator is required.

Only a successful live command contributes events to the current frame. A per-view player starts cues once per frame token, queues speech separately from effects and cancels old announcements on a new move. Pause, history seek, restart, import, switch and teardown stop/suppress historical cues. Re-rendering the same frame, legal-play browsing, rejected commands and unmuting do not replay announcements. **Sound on/off** is a local host control retained across game switches. Cues never change authoritative state or replay contents.

## Extending the component set

For behavior outside the current families, provide a `TabletopGameView` scene and a `TabletopPresentation` resource subtype. Chain `super._ready()` to initialize its per-view media player; implement `render(observation, legal_actions)` and `deactivate()`, honor `blocked`, release owned input/media on deactivation and use `request_command()` with the presented token. Register that scene/resource in the module without adding host branches.

`TabletopCardManager` owns its factory/input scope explicitly. Custom card views must not use the upstream root-scene lookup. `TabletopBoardCanvas` handles grid hit testing/focus and renders configured pieces/highlights; more elaborate boards can provide another Control under the same view contract.

## Client behavior provided to every game

A table owns its seed, session, pause state, full timeline, cursor and UI token. The workspace owns distinct table IDs and the active table. Common controls create/switch/restart/close, pause, undo/redo/seek, save and load. A new command from the middle of history creates a branch. A rejected command never discards the redo tail.

Loading validates the complete JSON archive first and attaches a new table only after success. Switching, seeking or resetting invalidates commands queued against the previous displayed frame. Closing and reopening does not reuse an ID.

## Acceptance for an added game

Exercise real legal/illegal transitions, rejection atomicity, terminal outcomes, observation isolation, legal-action IDs, full JSON replay, independent interleaved matches, common history controls and the mounted view. Include rule-specific boundaries rather than mirroring the implementation.

The current suites include three complete DouDiZhu matches played through configured controls, a second string-card engine using the same renderer, media cue routing/suppression, and a full 225-move Gomoku draw, two engine types in one workspace, two simultaneous card views, real Godot mouse/touch/key event paths, stale queued input, save/load, resize and teardown. Packaging reruns the actual scene suite from the generated PCK. Linux OpenGL captures verify the actual scenes at desktop and compact sizes.

Physical mouse/touch devices, DPI/OS behavior and signed/mobile/web distribution require their own acceptance in [#2](https://github.com/qigao/godot-tabletop/issues/2). For manual acceptance, create both games, play legal and rejected moves, review/branch/save/load, switch a hovered card hand to the board, resize, pause/resume, close all tables and create again. Touch must activate toolbar controls and each game move exactly once. Automated injection does not close that physical-device task.
