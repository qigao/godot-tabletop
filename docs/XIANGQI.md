# Xiangqi local rules

Choose **Xiangqi** and **New table** for a same-device game. The opening places 32 pieces on a 9 × 10 grid with Red at the bottom, moving first. Select a piece and a highlighted destination. Capture rings surround occupied destinations. The amber marks show the most recent move and the red ring shows a general in check.

The `xiangqi-local-v1` rules enforce the seven piece moves, the palace and river limits, horse legs, elephant eyes, cannon screens and the prohibition on exposing a general to check or leaving the two generals facing. The side with no legal move loses by checkmate or stalemate. Movement and these outcomes follow Articles 1–3 of the [World Xiangqi Rules](https://www.wxf-xiangqi.org/images/wxf-rules/2018_World_XiangQi_Rules_English2018.pdf).

The local profile ends the game at the third occurrence of the same board and side to move. A side loses if only that side gave check on every one of its moves across the repeated interval. Other repetitions draw. Tournament play requires a rules profile for perpetual chase and referee adjudication.

The module uses the shared move-board view. `presentation.tres` configures the board geometry, labels and observation fields, while `media.tres` supplies piece styles and the move cue. The shared client provides pause, history, save/load and independent tables. Replay stores row-major `move` commands with `from` and `to` and derives each position from the standard opening.

The regression suite compares 44 opening moves and 1,920 two-ply sequences against [published Xiangqi counts](https://talkchess.com/viewtopic.php?t=85880). It also checks piece restrictions, terminal results, viewport clicks/taps/keys, replay and compact layout using both source and PCK.
