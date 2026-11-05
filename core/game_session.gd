class_name TabletopSession
extends RefCounted
## One authority per match. Rejected commands never advance state or history.

signal changed(revision: int, events: Array)

var revision: int = 0
var rules: TabletopRules
var _state: Dictionary
var _seed: int
var _history: Array[Dictionary] = []

func _init(game_rules: TabletopRules, seed_value: int) -> void:
	rules = game_rules
	_seed = seed_value
	_state = rules.initial_state(seed_value)

func submit(seat: int, command: Dictionary, expected_revision: int) -> Dictionary:
	if expected_revision != revision:
		return {"ok": false, "error": "stale_revision"}
	var result := rules.apply(_state, seat, command)
	if not result.ok:
		return result
	_state = result.state
	_history.append({"seat": seat, "command": command.duplicate(true)})
	revision += 1
	changed.emit(revision, result.events)
	return {"ok": true, "revision": revision, "events": result.events.duplicate(true)}

func observe(seat: int) -> Dictionary:
	var view := rules.observe(_state, seat)
	view["revision"] = revision
	return view

func legal_actions(seat: int) -> Array[Dictionary]:
	return rules.legal_actions(_state, seat)

func active_seat() -> int:
	return rules.active_seat(_state)

func submit_action(seat: int, action_id: String, expected_revision: int) -> Dictionary:
	if expected_revision != revision:
		return {"ok": false, "error": "stale_revision"}
	for action in legal_actions(seat):
		if action.id == action_id:
			return submit(seat, action.command, expected_revision)
	return {"ok": false, "error": "unknown_legal_action"}

func authoritative_snapshot() -> Dictionary:
	return _state.duplicate(true)

func export_replay() -> Dictionary:
	# Privileged archive: the seed reveals the deal. This is not a player view.
	return {
		"schema": 1, "game_id": rules.game_id(), "rules_revision": rules.rules_revision(),
		"seed": _seed, "commands": _history.duplicate(true),
	}

static func from_replay(game_rules: TabletopRules, replay: Dictionary) -> Dictionary:
	for key in ["schema", "game_id", "rules_revision", "seed", "commands"]:
		if not replay.has(key):
			return {"ok": false, "error": "invalid_replay_format"}
	if not _is_integer(replay.schema) or not replay.game_id is String \
			or not replay.rules_revision is String or not _is_integer(replay.seed) \
			or replay.seed < 0 or replay.seed > 0xffffffff or not replay.commands is Array:
		return {"ok": false, "error": "invalid_replay_format"}
	if replay.schema != 1 or replay.game_id != game_rules.game_id() \
			or replay.rules_revision != game_rules.rules_revision():
		return {"ok": false, "error": "replay_version_mismatch"}
	var session := TabletopSession.new(game_rules, int(replay.seed))
	for entry in replay.commands:
		if not entry is Dictionary or not entry.has("seat") or not entry.has("command") \
				or not _is_integer(entry.seat) or entry.seat < 0 or not entry.command is Dictionary:
			return {"ok": false, "error": "invalid_replay_entry", "index": session.revision}
		var result := session.submit(int(entry.seat), entry.command, session.revision)
		if not result.ok:
			return {"ok": false, "error": "invalid_replay_command", "index": session.revision}
	return {"ok": true, "session": session}

static func _is_integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and value == int(value)
