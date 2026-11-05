# Architecture

## Local client first

The current deliverable is a Godot 4 client engine for local card and board games. Remote room authority and model inference are deferred. DouDiZhu and Gomoku are the concrete integrations; the grid fixture only tests the lower-level rules contract.

| Layer | Owns | Does not decide |
| --- | --- | --- |
| `TabletopRules` | Game profile, deterministic transition, observation, legal actions, active seat | Scene layout, animations or table lifecycle |
| `TabletopSession` | One authoritative state, command revision, accepted log | Which Godot view is mounted |
| `TabletopLocalTable` | One session, full command timeline, review cursor, pause, UI frame token | Card or board-specific commands |
| `TabletopWorkspace` | Independent tables, active table, creation/switch/close, validated replay import | Rules or rendering for an individual game |
| `TabletopGameModule` | Identity, seat count, rules script, view scene and presentation resource | A global live match |
| `TabletopGameView` | Observation rendering and command requests | Authoritative state mutation |
| `tabletop_app.gd` | Tabs, toolbar, history slider, dialogs, mounting the registered view | Game-specific state fields or move types |

## Rules and authority

`TabletopRules` defines game identity, rules revision, initial state, command application, seat-specific observation, legal-action enumeration, and active seat. Its value data must be replayable without a scene tree. Application returns a new state plus events, or an explicit rule error without changing the input state.

`TabletopSession.submit(seat, command, expected_revision)` rejects stale revisions before applying a command. Success commits once, advances the revision, records a detached command, and emits public events. Each match owns a different session. No autoload singleton owns live state.

`legal_actions(seat)` returns `{id, command}` entries. `submit_action(seat, id, expected_revision)` resolves an available ID through the same validator. Unknown, unavailable, or stale actions leave the match unchanged. DouDiZhu uses rank-multiset IDs and canonical owned physical cards; Gomoku uses `place:<cell>`. Other engines may define commands such as `{type: "move", from: 12, to: 28}` without changing the client host.

Observations contain only what that seat may see. The current local host presents the active seat's observation. It does not implement simultaneous remote players, spectators, or authenticated seats.

## History and stale input

A local table keeps the complete accepted timeline and a review cursor. Seeking reconstructs a fresh session from the seed and the chosen command prefix, through the same replay validator. It retains future commands for redo. A successful new command truncates the future at the cursor and appends the new branch; rejection preserves both state and timeline.

A session revision can repeat after undo and restart. Therefore the client uses a separate monotonically increasing frame token, scoped to a never-reused table ID. Moves, seeks, resets, pauses, and table switches invalidate old tokens. The view requests a command with the token of the frame it rendered; the workspace also checks that the table still exists and is active. Queued commands from detached views cannot affect a restored or newer match.

Pause blocks gameplay commands and displays an overlay. Review and common lifecycle controls remain available. Closing a table destroys its workspace ownership; other tables retain their exact state.

## Presentation and input

A module descriptor pairs the rules adapter with a `TabletopGameView` scene and typed presentation resource. Card-table and placement-board renderers/configurations are separate families. DouDiZhu and Gomoku use those shared scenes without individual game view scripts. Declarative value bindings translate observations into labels, hands and pieces, while legal actions enable configured controls. The catalog registers descriptors; the host mounts them without game/family branches. New interactions need a new component rather than rule-specific conditionals in the host. See CLIENT_ENGINE.md for the exact configuration boundary.

The card integration extends the pinned Card Framework outside its source tree. Each rendered card table owns an explicit manager and `TabletopInputScope`; it does not register a manager in root-scene metadata. The local hover scope chooses the hovered card, while adapter cleanup balances upstream static counters. Two live card views are exercised together and destroying one leaves the other's scope intact. Visual drag/drop cannot transfer cards around the rules authority.

The reusable card factory takes arbitrary string keys and display metadata. DouDiZhu rank/suit conversion belongs to its view, not the shared factory, card or hand. The board widget renders a configurable intersection grid, piece colors/text, focus, last-move and line highlights; its activated cell is interpreted by the game view. A game can supply a different widget while retaining the same view contract.

Media resources map table/card/piece artwork and local event cues. Only successful live commands provide events; invalidated/reviewed frames clear them. Each view deduplicates cue playback by token and owns independent effect/voice queues. Switching, seeking, restart, import and pause do not announce old events. Cues never decide transitions or alter replay. The host keeps a common sound toggle across game switches.

Native touch events activate custom cards/boards once. Emulated mouse events remain enabled for ordinary Godot toolbar controls; custom widgets ignore that duplicate mouse path. Keyboard focus and common client shortcuts coexist. Layout uses containers and a scrollable game slot with a 640 × 480 minimum desktop window.

The card interaction surface anchors hovered targets while card artwork expands and hit-tests painted transforms/order. Per-hand gestures retain a frame token, so range/drag previews can never transfer authoritative ownership. Timed motion and countdown policies are owned by the mounted view; the host preserves only local presentation state across unmounts. That state stays outside rule snapshots/replay. Settlement requests use the same table/token ownership boundary as gameplay. See INTERACTION.md for the exact baseline.

## Replay boundary

Schema 1 stores game ID, rules revision, seed, and ordered accepted commands. The deterministic deck uses fixed integer operations. Unsupported identity/revisions, malformed fields, invalid turns and illegal commands reject the archive. A loaded replay is completely validated before a new table is attached; existing tables are never replaced by partially loaded data.

Saving while reviewing writes the full timeline, including redo commands. Loading opens at the end. The review cursor, local pause state, tab order and UI selection are not match replay data.

Archives are privileged: a seed reconstructs every private hand. They are not multiplayer messages. During DouDiZhu bidding, the normal observation hides other hands, bottom cards and seed; after bidding only the bottom becomes public. Authoritative snapshots exist for local authority/tests.

## Future integrations

The existing action codec and committed oracle fixtures cover action ranks only. They do not construct full model features, run a trained model, or send requests. Inference and server-authoritative rooms remain separate deferred milestones [#3](https://github.com/qigao/godot-tabletop/issues/3) and [#4](https://github.com/qigao/godot-tabletop/issues/4).

Any later remote/model result must still pass the current rules validator with the correct match and revision. It must not become a card-node responsibility. The local client work does not imply that transport, reconnect, seat authentication, or model strength has been accepted.

## Development rules

Fail on broken invariants. Reject invalid player commands and external archives as explicit domain errors. Do not add silent fallbacks, historical API/ABI compatibility, installer tests, or consumer-package probes. External CI files use `curl`; the standard GDScript engine requires no Mono.
