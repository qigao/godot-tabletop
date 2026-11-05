# Legal actions and DouZero action mapping

## Match interface

`TabletopSession.legal_actions(seat)` returns no actions for an inactive seat or a finished game. During bidding it returns valid `bid:<value>` IDs. During play it enumerates rank-distinct combinations, filters responses against the last play, and includes `pass` only when following.

Each play has an ID such as `play:3,3,3,4,4`, a concrete `play` command, its sorted ranks, and classified pattern. The representative takes the lowest owned card IDs of each rank. Choosing different suits for identical ranks remains legal through the normal command API; it does not require another model action. The suit-independent ID remains stable when the hand's order or equivalent suit copies change.

`submit_action` resolves the current ID to concrete owned cards, then invokes the same command validator and replay log. It checks the expected revision first. An ID from another match/revision must not be reused without its context.

## Rank encoding

| Card | Local rank | DouZero rank |
| --- | --- | --- |
| 3 through A | 3 through 14 | 3 through 14 |
| 2 | 15 | 17 |
| Small joker | 16 | 20 |
| Big joker | 17 | 30 |
| Pass | `pass` action ID | Empty array |

The codec accepts integral JSON numbers and normalizes order. Invalid rank codes and moves absent from the supplied legal set are rejected. Bids are outside this play-phase codec. There is no network client or trained model in this milestone.

## Pinned independent oracle

Source: [kwai/DouZero at 718a5c9](https://github.com/kwai/DouZero/tree/718a5c920bf3361e34178a38f3b80458e176b351), specifically its unmodified `MovesGener.gen_moves()`. The fixture records source hashes and 935 raw generated rank actions across ten synthetic hands, including a 20-card hand.

Tests compare exact action sets. They subtract only six explicitly listed fixture actions, never run the raw oracle through our classifier to erase unexpected differences:

| Fixture difference | Count | Reason under `ddz-classic-v1` |
| --- | --- | --- |
| Both jokers as single wings | 2 | The profile rejects both jokers together as wings |
| Three same-rank single wings | 3 | The profile caps single wings at two cards per wing rank |
| Four same-rank single wings | 1 | The profile caps single wings at two cards per wing rank |

Thus the checked fixture contains 929 accepted rank actions and six named exclusions. This does not claim that an unmodified DouZero policy plays the same rule variant. A serving adapter must mask actions to this profile or explicitly choose a different versioned rules profile.

To regenerate, extract the pinned upstream source and run:

```sh
python scripts/update_douzero_oracle.py /absolute/path/to/DouZero-718a5c920bf3361e34178a38f3b80458e176b351
```

The updater executes only the pinned pure-Python generator and utility module, without importing the complete training environment. Ordinary CI checks the committed numeric fixture; it needs neither PyTorch nor NumPy.

## Additional acceptance and limits

- Twelve bounded hands are scanned through all physical-card subsets and compared with the constructive generator via the actual command validator, including every response kind and rocket.
- Ninety-six seeded complete mixed-combination games actually play all 14 pattern kinds, conserve all 54 cards after every action, and reproduce final state through JSON replay.
- The board fixture exercises the same legal-action/ID dispatch contract without card fields.
- Scene smoke checks legal-play cycling and confirms that browsing alone never advances the game.

These are finite acceptance cases. Full DouZero infoset/model-feature encoding, complete environment interoperability, inference transport, trained-policy evaluation, and real device input remain open in Issue #3 and the roadmap.
