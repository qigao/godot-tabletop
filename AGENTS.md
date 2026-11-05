# Project instructions

- Godot 4.6-stable, standard GDScript engine. Do not install Mono.
- Client first: finish local module/view integration, table lifecycle, input, history/replay, and packaging before remote rooms or AI. Issues #3 and #4 are deferred by the user's instruction.
- Conventional interaction behavior from the inspected reference is a required client acceptance criterion. Rules/replay counts alone do not establish UX acceptance. Maintain docs/INTERACTION.md and test actual viewport inputs, motion and lifecycle routes.
- Keep card-table and board components/configurations separate. Reference games use rules + presentation/media resources; new game-specific behavior must not become a host branch.
- Keep rules and match state independent of scenes, UI animations, networking, and autoload singletons.
- Each match owns a session. Invalid player commands return domain errors and must not mutate state/history.
- Fail fast on broken invariants. Do not add silent fallbacks or historical API/ABI compatibility layers.
- Keep upstream `addons/card-framework` pinned. Put integration changes in adapters and document any required upstream patch in `THIRD_PARTY.md`.
- Use `curl` to download external CI files. Do not add installer/consumer tests or environment-probing CI.
- Run `python scripts/check.py /absolute/path/to/Godot` after changes.
- Treat match drivers as tests, not production AI. Trained inference over HTTP/2/WebSocket is a deferred future integration, not part of the current client milestone.
- Preserve the evidence boundaries in README and the roadmap. A board-contract fixture is not a shipped board game; headless scene checks are not manual input/device acceptance.
