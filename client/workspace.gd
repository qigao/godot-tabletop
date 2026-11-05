class_name TabletopWorkspace
extends RefCounted
## Local client lifecycle. No card/board-specific state or transport code.

signal changed

const Catalog = preload("res://core/game_catalog.gd")

var active_id := -1
var _next_id := 1
var _tables: Dictionary = {}

func create_table(game_id: String, seed: int) -> int:
	var table := TabletopLocalTable.new(Catalog.module_for(game_id), seed)
	return _attach(table)

func _attach(table: TabletopLocalTable) -> int:
	if active_id != -1:
		_tables[active_id].token += 1
	var id := _next_id
	_next_id += 1
	_tables[id] = table
	active_id = id
	changed.emit()
	return id

func table_ids() -> Array:
	return _tables.keys()

func table_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in _tables:
		result.append({"id": id, "title": _tables[id].module.title})
	return result

func frame(id: int) -> Dictionary:
	var result: Dictionary = _tables[id].frame()
	result["table_id"] = id
	return result

func select_table(id: int) -> void:
	assert(_tables.has(id), "Unknown local table")
	if active_id != -1 and active_id != id:
		_tables[active_id].token += 1
	_tables[id].token += 1
	active_id = id
	changed.emit()

func close_table(id: int) -> void:
	assert(_tables.has(id), "Unknown local table")
	_tables.erase(id)
	if active_id == id:
		active_id = -1 if _tables.is_empty() else int(_tables.keys()[0])
	changed.emit()

func submit(id: int, command: Dictionary, token: int) -> Dictionary:
	if not _tables.has(id):
		return {"ok": false, "error": "table_closed"}
	if id != active_id:
		return {"ok": false, "error": "inactive_table"}
	var result: Dictionary = _tables[id].submit(command, token)
	if result.ok:
		changed.emit()
	return result

func seek(id: int, position: int) -> Dictionary:
	var result: Dictionary = _tables[id].seek(position)
	if result.ok:
		changed.emit()
	return result

func reset_table(id: int, seed: int) -> void:
	_tables[id].reset(seed)
	changed.emit()

func set_paused(id: int, value: bool) -> void:
	_tables[id].set_paused(value)
	changed.emit()

func export_replay(id: int) -> Dictionary:
	return _tables[id].export_replay()

func load_replay(text: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return {"ok": false, "error": "invalid_replay_json"}
	var archive: Dictionary = parser.data
	if not archive.has("game_id") or not archive.game_id is String \
			or not Catalog.contains(archive.game_id):
		return {"ok": false, "error": "unknown_replay_game"}
	var module := Catalog.module_for(archive.game_id)
	var restored := TabletopSession.from_replay(module.create_rules(), archive)
	if not restored.ok:
		return restored
	var table := TabletopLocalTable.new(module, int(archive.seed))
	table.adopt_replay(archive, restored.session)
	return {"ok": true, "table_id": _attach(table)}

func snapshot(id: int) -> Dictionary:
	return _tables[id].snapshot()
