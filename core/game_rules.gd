@abstract
class_name TabletopRules
extends RefCounted
## Rules own value data only. No scenes, animation, network, or global singleton.

@abstract func game_id() -> String
@abstract func rules_revision() -> String
@abstract func initial_state(seed_value: int) -> Dictionary
@abstract func apply(state: Dictionary, seat: int, command: Dictionary) -> Dictionary
@abstract func observe(state: Dictionary, seat: int) -> Dictionary
@abstract func legal_actions(state: Dictionary, seat: int) -> Array[Dictionary]
@abstract func active_seat(state: Dictionary) -> int
