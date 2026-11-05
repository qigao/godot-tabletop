extends SceneTree

const Gomoku = preload("res://games/gomoku/rules.gd")
const Catalog = preload("res://core/game_catalog.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	_gomoku()
	_workspace()
	_invalid_archives()
	print("Client engine: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _gomoku() -> void:
	var session := TabletopSession.new(Gomoku.new(), 1)
	_check(session.legal_actions(0).size() == 225 and session.legal_actions(1).is_empty(), "Board opening actions")
	_check(session.submit_action(0, "place:112", 0).ok, "Place center")
	var before := session.authoritative_snapshot()
	for command in [{"type": "place", "cell": 112}, {"type": "place", "cell": -1},
			{"type": "place", "cell": 225}, {"type": "place", "cell": 1.5},
			{"type": "place", "cell": "3"}, {"type": "place", "cell": true}, {"type": "pass"}, {}]:
		_check(not session.submit(1, command, 1).ok, "Reject invalid placement")
		_check(session.authoritative_snapshot() == before and session.revision == 1, "Board rejection atomic")
	_check(session.submit(0, {"type": "place", "cell": 113}, 1).error == "wrong_turn", "Board turn enforced")
	for black in [[0,1,2,3,4], [0,15,30,45,60], [0,16,32,48,64],
			[14,28,42,56,70], [224,208,192,176,160], [0,1,2,4,5,3]]:
		var match_session := TabletopSession.new(Gomoku.new(), 0)
		for move in range(black.size()):
			_check(match_session.submit(0, {"type": "place", "cell": black[move]}, match_session.revision).ok, "Winning sequence black")
			if move != black.size() - 1:
				_check(match_session.submit(1, {"type": "place", "cell": 90 + move * 2}, match_session.revision).ok, "Winning sequence white")
		var result := match_session.authoritative_snapshot()
		_check(result.phase == "finished" and result.winner == 0 and result.winning_cells.size() == black.size(), "Win directions, edges, overline")
		_check(match_session.legal_actions(0).is_empty() and not match_session.submit(0, {"type":"place","cell":200}, match_session.revision).ok, "Finished board locked")
		var restored := TabletopSession.from_replay(Gomoku.new(), JSON.parse_string(JSON.stringify(match_session.export_replay())))
		_check(restored.ok and restored.session.authoritative_snapshot() == result, "Board win JSON replay")
	var wrap := TabletopSession.new(Gomoku.new(), 0)
	for cell in [12,13,14,15,16]:
		wrap.submit(0, {"type":"place","cell":cell}, wrap.revision)
		wrap.submit(1, {"type":"place","cell":90 + (cell-12)*2}, wrap.revision)
	_check(wrap.authoritative_snapshot().phase == "playing", "Rows cannot wrap")
	var draw := TabletopSession.new(Gomoku.new(), 0)
	var cells: Array = [[], []]
	for row in range(15):
		for column in range(15):
			cells[0 if (row + 2 * column) % 4 < 2 else 1].append(row * 15 + column)
	for move in range(225):
		var seat := move % 2
		_check(draw.submit(seat, {"type":"place","cell":cells[seat].pop_front()}, draw.revision).ok, "Full board draw placement")
	var end := draw.authoritative_snapshot()
	_check(end.phase == "finished" and end.winner == -1 and end.moves == 225, "Full board draw")
	var replayed := TabletopSession.from_replay(Gomoku.new(), JSON.parse_string(JSON.stringify(draw.export_replay())))
	_check(replayed.ok and replayed.session.authoritative_snapshot() == end, "Full board draw replay")

func _workspace() -> void:
	var client := TabletopWorkspace.new()
	var card_id := client.create_table("doudizhu", 42)
	var opening := client.frame(card_id)
	_check(client.submit(card_id, {"type":"bid","value":3}, opening.token).ok, "Module starts card session")
	var card_snapshot := client.snapshot(card_id)
	var board_id := client.create_table("gomoku", 7)
	_check(client.snapshot(card_id) == card_snapshot, "Creating board preserves card table")
	_check(client.submit(card_id, {"type":"pass"}, opening.token).error == "inactive_table", "Inactive view cannot act")
	var board_open := client.frame(board_id)
	_check(client.submit(board_id, {"type":"place","cell":112}, board_open.token).ok, "Module starts board session")
	var one := client.snapshot(board_id)
	var frame := client.frame(board_id)
	_check(client.submit(board_id, {"type":"place","cell":113}, frame.token).ok, "Second board move")
	var two := client.snapshot(board_id)
	var stale_token: int = client.frame(board_id).token
	_check(client.seek(board_id, 1).ok and client.snapshot(board_id) == one, "Undo restores exact state")
	_check(client.submit(board_id, {"type":"place","cell":114}, stale_token).error == "stale_client_frame", "History invalidates old UI frame")
	_check(client.seek(board_id, 2).ok and client.snapshot(board_id) == two, "Redo restores exact state")
	client.seek(board_id, 1)
	_check(client.submit(board_id, {"type":"place","cell":114}, client.frame(board_id).token).ok, "New move branches history")
	_check(client.frame(board_id).length == 2 and not client.seek(board_id, 3).ok, "Branch discards old redo tail")
	client.set_paused(board_id, true)
	var paused := client.frame(board_id)
	var immutable := client.snapshot(board_id)
	_check(client.submit(board_id, {"type":"place","cell":115}, paused.token).error == "table_paused", "Pause rejects commands")
	_check(client.snapshot(board_id) == immutable, "Pause leaves game state unchanged")
	client.set_paused(board_id, false)
	var before_switch: int = client.frame(board_id).token
	client.select_table(card_id)
	client.select_table(board_id)
	_check(client.submit(board_id, {"type":"place","cell":115}, before_switch).error == "stale_client_frame", "Returning to table invalidates detached view")
	var archive := JSON.stringify(client.export_replay(board_id))
	client.seek(board_id, 0)
	_check(client.snapshot(board_id).moves == 0 and client.frame(board_id).length == 2, "Seek preserves complete replay")
	var imported := client.load_replay(archive)
	_check(imported.ok and client.snapshot(imported.table_id) == immutable, "Replay loads a new independent table")
	var closed_id: int = imported.table_id
	var closed_token: int = client.frame(closed_id).token
	client.close_table(closed_id)
	_check(client.submit(closed_id, {"type":"place","cell":0}, closed_token).error == "table_closed", "Closed view cannot act")
	var newer := client.create_table("gomoku", 0)
	_check(newer > closed_id, "Table IDs never reused")
	var old: int = client.frame(newer).token
	client.reset_table(newer, 13)
	_check(client.submit(newer, {"type":"place","cell":0}, old).error == "stale_client_frame", "Restart invalidates old UI frame")
	_check(client.snapshot(card_id) == card_snapshot, "Interleaved lifecycle preserves other rules engine")
	var snapshot := client.snapshot(newer)
	client.frame(newer).observation.board[0] = 1
	_check(client.snapshot(newer) == snapshot, "Client frame is detached value data")

func _invalid_archives() -> void:
	var client := TabletopWorkspace.new()
	var id := client.create_table("gomoku", 0)
	client.submit(id, {"type":"place","cell":112}, client.frame(id).token)
	var original := client.snapshot(id)
	var original_ids := client.table_ids()
	var malformed: Array = ["", "null", "[]", "{}", "{", "{\"game_id\":\"missing\"}"]
	for field in ["schema", "game_id", "rules_revision", "seed", "commands"]:
		var data := client.export_replay(id)
		data.erase(field)
		malformed.append(JSON.stringify(data))
	for patch in [{"commands":[null]}, {"commands":["bad"]}, {"commands":[{"seat":0}]},
			{"commands":[{"seat":false,"command":{}}]}, {"commands":[{"seat":0,"command":"bad"}]},
			{"commands":[{"seat":1,"command":{"type":"place","cell":1}}]},
			{"seed":"bad"}, {"seed":-1}, {"schema":true}, {"rules_revision":"wrong"}]:
		var data := client.export_replay(id)
		data.merge(patch, true)
		malformed.append(JSON.stringify(data))
	for text in malformed:
		_check(not client.load_replay(text).ok, "Malformed replay rejected")
		_check(client.table_ids() == original_ids and client.active_id == id and client.snapshot(id) == original,
				"Malformed replay cannot replace or mutate a live table")
