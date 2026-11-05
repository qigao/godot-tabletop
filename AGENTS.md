# Project instructions

- Godot 4.6-stable, standard GDScript engine. Do not install Mono.
- Keep rules and match state independent of scenes, UI animations, networking, and autoload singletons.
- Each match owns a session. Invalid player commands return domain errors and must not mutate state/history.
- Fail fast on broken invariants. Do not add silent fallbacks or historical API/ABI compatibility layers.
- Keep upstream `addons/card-framework` pinned. Put integration changes in adapters and document any required upstream patch in `THIRD_PARTY.md`.
- Use `curl` to download external CI files. Do not add installer/consumer tests or environment-probing CI.
- Run `python scripts/check.py /absolute/path/to/Godot` after changes.
- Treat the M0 driver as tests, not a production AI. Trained play uses a separate DouZero inference service over HTTP/2/WebSocket.
- Preserve the evidence boundaries in README and the roadmap. A board-contract fixture is not a shipped board game; headless scene checks are not manual input/device acceptance.
