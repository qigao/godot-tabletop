# Architecture

## Boundaries

The reusable layer is a per-match command authority. It must work for card games, piece-placement games, and chess-style move games without depending on any particular scene hierarchy.

`TabletopRules` defines six operations: game identity, rules revision, initial state, command application, seat-specific observation, and legal-action enumeration. A rules module uses value data only. It returns a new state and public events for a successful command, or a rule error without changing its input state.

`TabletopSession` owns one state, seed, revision, and accepted-command log. `submit(seat, command, expected_revision)` rejects stale revisions before asking the rules to apply the command. Successful submission commits once, increments revision, and then emits events. The returned result contains events, not the authoritative state. Each match gets a distinct session; no autoload singleton owns matches.

`legal_actions(seat)` returns module-defined `{id, command}` entries for the acting seat. `submit_action(seat, id, expected_revision)` checks the revision before resolving the ID, then submits the resolved command through the same validator. Unknown, unavailable, or stale actions do not advance the match. The grid fixture supplies `place:<cell>` actions through this interface; the common core has no card-specific fields.

DouDiZhu enumerates one action per rank multiset and selects the lowest owned physical card IDs as its representative. Equivalent suits retain the same action ID. The production generator constructs pattern families and bounded wing selections; the exponential physical-subset scan exists only in acceptance tests. IDs are scoped by the match and revision; future network/inference messages must include that context.

The Godot view submits commands and reads observations. Animation never decides ownership, whose turn it is, or whether a play is legal. The card addon handles presentation. Its visual movement history is not the game replay and is not used for game undo.

## Adding a game

1. Add a `TabletopRules` implementation under `games/<id>/`.
2. Give its rule profile a concrete revision; unsupported replay revisions fail rather than silently adopting changed rules.
3. Register its rules in `TabletopCatalog` and provide a view adapter.
4. Test command legality, rejected-command atomicity, observations, outcome, and JSON replay.

`tests/fixtures/grid_rules.gd` proves that board-cell commands and two-player turns run through the same session/replay code without a hand, deck, landlord, or Godot node.

The current product UI renders one DouDiZhu table. Rule-session isolation is tested; simultaneous multi-table UI interaction is not yet accepted. Upstream static hover counters are a presentation constraint to address before that milestone.

## Replay and hidden information

Replay schema 1 contains game ID, rules revision, initial seed, and ordered accepted commands. The deck uses fixed integer operations rather than an engine-version-dependent RNG. JSON decoding is accepted for integral numeric card IDs and bids; fractional values are rejected.

Replay is a privileged match archive: its seed reconstructs every private hand. It is not a player observation or a multiplayer message. During bidding, observations hide other hands, the bottom cards, and the seed. After bidding, only the bottom cards become public. Full authoritative snapshots exist for local authority/testing, not client transport.

## DouZero and networking direction

The first UI is hotseat and includes no production bot. The complete-match test driver is only an acceptance tool.

The next AI adapter should use a separately hosted DouZero inference service over HTTP/2 or WebSocket. It receives the acting seat's observation and legal-action representation. A returned action still passes through `submit` with the expected revision. Training and inference implementation do not belong in card nodes.

The current DouZero codec handles action ranks and pass only, and resolves decoded outputs against the supplied legal-action set. It does not construct the full model observation/features, send network requests, or run a trained model. See `DOUZERO_ACTIONS.md` for pinned oracle evidence and rule-profile differences.

Online rooms will own the authoritative session on the server, derive the seat from the authenticated connection, and distribute separate observations per player. A peer must not choose its own seat or receive the live seed/archive. Reconnect should use observation plus revision; command deduplication and stale inference cancellation require their own acceptance before claiming online support.

## Development rules

Fail on broken invariants. Reject invalid player commands as explicit domain errors. Do not add silent fallbacks, historical API/ABI compatibility, installer tests, or consumer-package probes. Download external CI files with `curl`; use the standard GDScript engine without Mono.
