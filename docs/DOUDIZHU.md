# DouDiZhu profile: ddz-classic-v1

## Deck and round

Three seats use one 54-card deck. IDs 0..51 are four suits for each rank 3..A..2; IDs 52/53 are small/big joker. Rank order is 3 < ... < A < 2 < small joker < big joker.

The initial deal starts bidding at seat 0. Each seat bids once, choosing 0 (pass) or a higher value in 1..3. A bid of 3 ends bidding immediately. Three passes redeal using the next deterministic seed and rotate the first bidder. The highest bidder receives the three bottom cards and leads.

## Accepted combinations

| Kind | Form |
| --- | --- |
| Single / pair / triple | One, two, or three cards of one rank |
| Triple + single / pair | A triple and one distinct single or pair |
| Straight | At least five consecutive single ranks, at most A |
| Pair straight | At least three consecutive pairs, at most A |
| Airplane | At least two consecutive triples, at most A |
| Airplane + single wings | Consecutive triples plus one single per triple |
| Airplane + pair wings | Consecutive triples plus one distinct pair per triple |
| Four + two singles | Four of one rank plus two single cards |
| Four + two pairs | Four of one rank plus two distinct pairs |
| Bomb | Four cards of one rank |
| Rocket | Both jokers |

For the single-wing forms, a pair may supply two single wings. A triple cannot be used as three single wings. Body ranks cannot also be wing ranks, and both jokers cannot be used together as the two single wings. Two quads are not treated as four-with-two-pairs. These choices are explicit profile rules, not a claim that every regional variant agrees.

Ordinary responses must have the same kind and card count, with a higher main rank. A bomb beats ordinary combinations; a higher bomb beats a bomb. Rocket beats everything else. Neither 2 nor a joker participates in a chain.

## Passing and outcome

The leader cannot pass. After two consecutive passes, the last successful player leads a fresh trick. A player wins for their side as soon as their hand is empty.

Base multiplier is the winning bid. Each played bomb or rocket doubles it. A landlord win before either farmer has played is spring; a farmer win after the landlord has played only once is reverse spring. Either doubles the multiplier.

When the landlord wins, scores are `+2m` for the landlord and `-m` per farmer. When farmers win, signs reverse. No entry fees or monetary accounting are implemented.

## Validation boundaries

Tests cover all named combination types, negative boundaries, bids, passes, privacy, scoring fixtures, and complete replay. The 32 full-match acceptance runs use single-card plays and passes. End-to-end mixed-combination agent play, DouZero legal-action mapping, regional profiles, and external rule-oracle comparison remain separate milestones.
