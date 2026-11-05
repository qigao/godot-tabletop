# Card interaction baseline and acceptance

Interaction quality is a mandatory client acceptance criterion. Rule/session checks alone do not establish that a client meets the reference workflow. The following behaviors are implemented by the common card components, then configured by the DouDiZhu example. Art, positioning, timing and optional input modes remain customizable.

## Inspected reference and scope

Reference: [blmz/GODOT-DouDiZhu](https://github.com/blmz/GODOT-DouDiZhu), commit `58e8daa59efb38a4afa1d6de2da5752469f5a019`. The inspected `脚本/手牌管理器.gd`, `脚本/扑克牌.gd`, `脚本/时钟倒计时.gd`, `结算界面.gd` and associated scenes establish the behavior below. This project independently implements those interactions with its own components and assets; no upstream code/media is imported.

The actual reference uses hover expansion and click selection. Sweep selection and drag-to-play are additional configurable modes here; the earlier assumption that the reference already shipped them was incorrect. The reference's computer opponents remain outside this client task. Local hotseat continues to use the same rules authority without adding an AI.

| Reference behavior | Common implementation | Configurable data |
| --- | --- | --- |
| Curved hand, hover separation, visible selection | `TabletopSelectionHand`, `TabletopPlayingCard` | Fan curves, hover spread/scale, persistent selection lift and movement time |
| Click card and submit/pass | Stable hand input surface and legal-action controls | Command dictionaries, selection equivalence, button visibility and labels |
| Timed sequential dealing | Card-table motion layer; local faces and opponent backs | Enable/skip/reduced motion, deal interval and travel time |
| Bottom reveal and played-card display | `TabletopCardRow` public zones | Zone positions, dimensions, face/hidden bindings and captions |
| Three-player positions, counts, role and calls | `TabletopSeatBadge`, relative seat anchors | Seat order, anchors, portrait/back images, role/count text bindings |
| Active turn countdown | `TabletopTurnClock` | Seconds and ordered legal timeout actions |
| Voice, card effects, low-card warnings and background changes | Independent effect/voice/notice/music channels | Event filters/conditions, streams, loop imports and volume |
| Outcome presentation, retry and leave | Settlement panel plus generic host lifecycle | Result condition and bound title/score text; new round or close |
| Optional sweep/group drag | Same hand controller, visual ghosts and target feedback | Enable modes, threshold, drop action and right-click clear |

## Input contract

A click/tap toggles selection immediately; selection remains visibly raised. Mouse movement over an unpressed hand expands the hovered card and separates its neighbors. The hand anchors the hovered target while its artwork expands, then hit-tests actual painted transforms/order, including raised selections. This prevents hover motion from changing a press target while keeping visible neighboring cards selectable. Individual cards retain keyboard focus and share this controller rather than competing for overlapping mouse events.

Horizontal motion after a press selects/deselects the full crossed range, including cards skipped by a fast pointer event. Dragging upward starts a preview of the selected group; dragging an unselected card starts a new single-card group. Releasing over the highlighted play area submits the configured action only if its selection matches an available legal action. An illegal or outside drop keeps the cards and selection in the hand and displays feedback. Visual ghosts never move authoritative ownership.

Touch uses the original touch pointer. Emulated mouse input remains available to ordinary Godot controls and is ignored by custom hand input, so one tap cannot toggle twice. A second pointer does not take over an active gesture. Canceled touch, focus loss, Escape, pause, frame change, switch and teardown cancel the old gesture. Right-click/Escape and **Clear** clear selection. Space/Enter toggles a focused card; arrows move focus, and Shift+arrow extends selection.

Any submitted action still carries the rendered table/frame token. Input cannot bypass rules, replay/history, turn checks, canonical equivalence or stale-frame validation.

## Motion and local clock lifecycle

**Skip motion** completes the current deal visually without advancing rules. The host's **Motion on/off** setting persists across game families. Reduced motion keeps selection/feedback readable and removes card travel/burst motion. New live events may animate a reveal or played-card ghost; seek, replay import and returning to a table display the current state without replaying old motion or announcements.

The countdown is a local active-view policy, not a server time authority. Deal/play motion suspends its elapsed time. Pause and inactive tables freeze it. A detached card view saves remaining time in local presentation state and restores it only for the same seed/cursor, with the new frame token. This UI state is not a rule state or replay archive. Historical/imported frames show a stopped clock and cannot autonomously append commands.

On expiry, the configured priority list tries only currently visible, enabled legal actions. The sample uses pass, then no-bid. A leading player has no legal pass, so expiry asks the player to choose a legal play rather than inventing an autoplay strategy. Old timer callbacks cannot act after pause, seek, restart, switch or close.

Settlement blocks hand/gameplay actions and shows the actual bound outcome/scores. **New round** asks the host to reset the current table with the next seed; **Close table** asks it to close that table. Both requests use the frame token. A stale result panel cannot restart or close a newer match. Common history controls remain available for review.

## Configuration points

- `client/presentation/card_interaction.gd`: selection/hover parameters, pointer threshold, sweep/drop toggles, drop action, keyboard range and clear behavior.
- `client/presentation/card_motion.gd`: deal/play/reveal, event feedback and result timing.
- `games/doudizhu/presentation.tres`: seat anchors, public zones, role/count bindings, timeout policy, motion event targets, visual callouts and result condition.
- `games/doudizhu/media.tres`: replaceable faces/backs/portraits, pattern/low-card narration, effects and background music changes.

The card renderer has no imports from DouDiZhu rules and no branches on individual game command/event identifiers. The host receives generic command/lifecycle requests. A placement board remains a separate component; it does not inherit the card gesture state machine.

## Evidence and remaining acceptance

`tests/interaction.gd` injects actual Godot viewport mouse/touch/key events. It exercises deal/reveal timing, stable overlapping-card hits, click/sweep/drag, illegal drops, cancellation, paused/historical timers, configured timeout commands, switching during a deal, a complete game and pointer-driven result retry. The same suite runs from the packaged PCK, in addition to the ordinary scene checks. The other suites continue to cover rules, three complete configured games, alternate string-card engines and replay isolation.

Linux native OpenGL acceptance captures desktop, compact card/board and settlement layouts. `client-interactions.gif` is assembled from actual rendered deal, hover, selection and drag/drop frames; it is not a generated mockup. CI uploads the motion/layout captures alongside each platform's runnable client.

These checks establish the implemented routes and rendered behavior. Physical mouse/touch devices, speaker quality, DPI/OS focus behavior and production art/narration remain [#2](https://github.com/qigao/godot-tabletop/issues/2). Test totals and a successful replay do not by themselves establish subjective usability or device acceptance. Remote rooms and AI remain deferred.
