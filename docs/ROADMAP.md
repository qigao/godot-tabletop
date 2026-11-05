# Roadmap

## M0: Offline foundation

- [x] Godot 4.6 project and pinned MIT Card Framework dependency.
- [x] Scene-independent per-match state, commands, observations, and replay.
- [x] DouDiZhu bidding, combinations, turn/trick resolution, outcome, and scoring.
- [x] Playable local three-seat hotseat view using the actual addon.
- [x] Rule acceptance, 32 full-match JSON replays, isolation, board-contract fixture, UI smoke.
- [ ] Linux/Windows/macOS CI accepted at the exact implementation HEAD.
- [ ] Manual rendered UI, mouse, resize, and touch acceptance on target devices.

## M1: DouDiZhu rules and inference acceptance

- [ ] Independently validate mixed-combination full games, especially airplane wings and four-with-two variants.
- [ ] Implement complete legal-action enumeration and verify action/observation mapping against DouZero.
- [ ] Define HTTP/2 and WebSocket inference messages with game/rules identity, seat observation, revision, and action IDs.
- [ ] Integrate separately deployed trained inference; reject stale or illegal responses through the same authority.
- [ ] Keep a held-out evaluation set and report actual strength only after complete real matches.

## M2: Online rooms and distribution

- [ ] Server authority with connection-bound seats and separate private observations.
- [ ] Reconnect, command deduplication, replay publication after the hand, and timeout/disconnect policies.
- [ ] Multi-table presentation ownership; eliminate cross-table interaction through addon static state.
- [ ] Desktop/web exports and real device input acceptance, with downloadable build artifacts.

## M3: Board-game extension

- [ ] Ship a first board-game module (freestyle Gomoku as the initial reference) through the common catalog/session/replay interface.
- [ ] Separate piece/grid rendering from card rendering.
- [ ] Add move, turn, outcome, replay, and simultaneous independent-session acceptance.

Chess/Xiangqi and additional card games should get their own rules and profile tests. They must not inherit DouDiZhu-specific fields or card-container ownership.
