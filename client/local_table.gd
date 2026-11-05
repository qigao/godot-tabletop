class_name TabletopLocalTable
extends RefCounted

var module: TabletopGameModule
var seed_value: int
var paused := false
var token := 1
var cursor := 0
var _session: TabletopSession
var _timeline: Array[Dictionary] = []
var _events: Array = []

func _init(game_module: TabletopGameModule, seed: int) -> void:
	module = game_module
	seed_value = seed
	_session = TabletopSession.new(module.create_rules(), seed)

func frame() -> Dictionary:
	var seat := _session.active_seat()
	assert(seat >= 0 and seat < module.seat_count, "Rules adapter returned an invalid active seat")
	return {"game_id": module.id, "title": module.title, "seed": seed_value,
			"token": token, "paused": paused, "seat": seat,
			"cursor": cursor, "length": _timeline.size(),
			"events": _events.duplicate(true),
			"observation": _session.observe(seat), "legal_actions": _session.legal_actions(seat)}

func submit(command: Dictionary, expected_token: int) -> Dictionary:
	if expected_token != token:
		return {"ok": false, "error": "stale_client_frame"}
	if paused:
		return {"ok": false, "error": "table_paused"}
	var seat := _session.active_seat()
	var result := _session.submit(seat, command, _session.revision)
	if result.ok:
		_timeline.resize(cursor)
		_timeline.append({"seat": seat, "command": command.duplicate(true)})
		cursor += 1
		_events = result.events.duplicate(true)
		token += 1
	return result

func seek(position: int) -> Dictionary:
	if position < 0 or position > _timeline.size():
		return {"ok": false, "error": "history_position_out_of_range"}
	var archive := export_replay()
	archive.commands = archive.commands.slice(0, position)
	var restored := TabletopSession.from_replay(module.create_rules(), archive)
	assert(restored.ok, "Committed local history must replay")
	_session = restored.session
	cursor = position
	invalidate_frame()
	return {"ok": true}

func reset(seed: int) -> void:
	seed_value = seed
	_session = TabletopSession.new(module.create_rules(), seed)
	_timeline.clear()
	cursor = 0
	paused = false
	invalidate_frame()

func set_paused(value: bool) -> void:
	paused = value
	invalidate_frame()

func invalidate_frame() -> void:
	token += 1
	_events.clear()

func export_replay() -> Dictionary:
	return {"schema": 1, "game_id": module.id, "rules_revision": _session.rules.rules_revision(),
			"seed": seed_value, "commands": _timeline.duplicate(true)}

func adopt_replay(archive: Dictionary, restored: TabletopSession) -> void:
	_session = restored
	_timeline.assign(archive.commands.duplicate(true))
	cursor = _timeline.size()
	invalidate_frame()

func snapshot() -> Dictionary:
	return _session.authoritative_snapshot()
