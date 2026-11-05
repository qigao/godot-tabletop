# Roadmap

## Current priority: Godot 4 local client engine

The user requested completion of the reusable local client before remote rooms or AI. The project uses Godot 4.6-stable as its pinned 4.x baseline. Track the client milestone in [#7](https://github.com/qigao/godot-tabletop/issues/7), the concrete board integration in [#5](https://github.com/qigao/godot-tabletop/issues/5), and physical device/distribution acceptance in [#2](https://github.com/qigao/godot-tabletop/issues/2).

- [x] Independent rules/session authority, observations, revision checks and deterministic replay.
- [x] DouDiZhu local hotseat with bidding, 14 combination types, outcomes and scoring.
- [x] Complete rank-distinct legal actions and a legal-play selection browser.
- [x] Module descriptors pair rules adapters and views; the client host has no game-specific branches.
- [x] Multi-table workspace: create, switch, restart, pause, close and independent progress.
- [x] Common undo/redo, replay seek and history branching.
- [x] File-picker save/load, full archive validation and new-table replay import.
- [x] Monotonic UI tokens reject stale/detached commands after lifecycle changes.
- [x] Per-view card managers/input scopes, generic card metadata, separate board/piece widget.
- [x] Playable 15 × 15 freestyle Gomoku using the same module/session/client contracts.
- [x] Rule, workspace, scene, simulated mouse/touch/key, resize and lifecycle acceptance.
- [x] Real local OpenGL layout captures at 1280 × 800 and 800 × 600.
- [x] Runnable development client packaging with PCK scene acceptance; three-platform CI publishes bundles.
- [ ] Physical target-device input/DPI acceptance; signed production distribution, web/mobile exports (#2).

The exact implementation commit and three-platform CI result are recorded in the pull request and tracking issue. Automation verifies event routing and actual scene rendering; it does not establish physical touchscreen behavior.

## Configured presentation ([#9](https://github.com/qigao/godot-tabletop/issues/9))

- [x] Separate card-table and placement-board resource schemas and renderers.
- [x] Declarative observation/seat/selection bindings and legal-action-driven controls.
- [x] DouDiZhu and Gomoku converted to configuration without individual game view scripts.
- [x] Replaceable card/table/piece images and event-driven local voice/effect streams.
- [x] Per-view cue ownership, mute, cancellation and silent history/import/switch behavior.
- [x] Three complete configured DouDiZhu games, second string-card engine reuse and imported-asset acceptance.

This covers the current components. New chess-style piece/move interactions require a separate board component; a rules script cannot infer layout. Physical speaker/input and production voice/art quality remain device/product acceptance. Exact-HEAD three-platform results are recorded in the PR and issue.

## Required interaction baseline ([#11](https://github.com/qigao/godot-tabletop/issues/11))

The user requires the conventional reference workflow, with variations customizable through components/resources. Passing rule/replay tests alone does not complete this milestone.

- [x] Curved hand, stable painted-card hit regions, hover expansion, persistent selection lift and smooth movement.
- [x] Viewport mouse/touch/key routes, click/sweep/group drag, clear/cancel, legal-target feedback and stale input isolation.
- [x] Relative players/counts/roles/backs, public bottom and played-card zones.
- [x] Sequential deal/reveal/play motion, skip/reduced motion and cancellation on lifecycle changes.
- [x] Active-view countdown, configured legal timeout actions and inactive/paused/review isolation.
- [x] Pattern/low-card callouts, separate voice/warning/effect streams, looping music and configured music changes.
- [x] Settlement with actual scores, new-round/close controls and stale callback rejection.
- [x] Actual viewport scenarios and native motion/layout capture; packaged scene and interaction acceptance.
- [x] Modal/window/application suspension with stale-lease rejection, retained clock/pause state, frozen replay saves and motion-enabled input checks ([#13](https://github.com/qigao/godot-tabletop/issues/13)).

Exact implementation/three-platform evidence is recorded in #11 and its PR. Physical device/audio acceptance remains #2. The inspected reference itself uses click selection; sweep/drop are additional configurable modes. See INTERACTION.md for source mapping and evidence boundaries.

## Accepted rule/action evidence

- 32 complete seeded single/pass DouDiZhu matches.
- 96 complete seeded mixed-combination matches, with all 14 kinds actually played and JSON replay.
- Bounded exhaustive subset comparisons for the legal action generator.
- 935 pinned upstream action outputs, six explicit rule-profile exclusions, stable IDs and revision-checked dispatch.
- Gomoku horizontal/vertical/diagonal and edge wins, overline behavior, no row wrapping, a full 225-move draw, and JSON replay.

These are deterministic acceptance drivers. They do not implement a production opponent or prove trained-agent strength.

## Additional games

Chess/Xiangqi and further card games get their own rules/profile and view adapters through the current descriptor contract. A chess move is an engine-specific command, not a new host code path. Each game needs its own real outcome/replay/interaction acceptance.

## Deferred: trained inference ([#3](https://github.com/qigao/godot-tabletop/issues/3))

- Construct and independently validate full DouZero observations/model features and whole-environment compatibility.
- Define HTTP/2/WebSocket messages with game/rules identity, seat observation, revision, and legal actions.
- Integrate separately deployed trained inference and reject stale/illegal responses through authority.
- Evaluate complete real matches using held-out data before claiming model strength.

The existing action codec and oracle fixtures stay as rule acceptance; no new model or transport work is part of the client milestone.

## Deferred: server-authoritative rooms ([#4](https://github.com/qigao/godot-tabletop/issues/4))

- Connection-bound seats, server authority and separate private observations.
- Reconnect, command deduplication, post-hand replay publication and timeout/disconnect policies.
- Remote room lifecycle and concurrency acceptance.

Local table lifecycle and desktop development bundles belong to the current client milestone, independently of this future transport work.
