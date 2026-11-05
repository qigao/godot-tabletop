class_name TabletopCuePlayer
extends Node
## Only committed live transitions produce cues. History navigation is silent.

signal cue_started(id: String)

var media: TabletopMediaPack
var muted := false:
	set(value):
		muted = value
		if muted:
			stop()
var _last_token := -1
var _players: Dictionary = {}
var _queues: Dictionary = {"effect": [], "voice": []}

func _ready() -> void:
	for channel in _queues:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players[channel] = player
		player.finished.connect(_next.bind(channel))

func present(frame: Dictionary) -> void:
	if frame.token == _last_token:
		return
	_last_token = frame.token
	if frame.events.is_empty() or frame.paused:
		stop()
		return
	if muted:
		return
	# New live action supersedes unfinished announcements from the old turn.
	stop()
	for event in frame.events:
		for cue in media.cues:
			if cue.event_type != event.type:
				continue
			var matches := true
			for key in cue.fields:
				if TabletopBinding.read({"get": "event." + key}, {"event": event}) != cue.fields[key]:
					matches = false
			if matches:
				_queues[cue.channel].append(cue)
	for channel in _queues:
		_next(channel)

func _next(channel: String) -> void:
	if _queues[channel].is_empty():
		return
	var cue: TabletopAudioCue = _queues[channel].pop_front()
	var player: AudioStreamPlayer = _players[channel]
	player.stream = cue.stream
	player.volume_db = cue.volume_db
	player.play()
	cue_started.emit(cue.id)

func stop() -> void:
	for channel in _queues:
		_queues[channel].clear()
		_players[channel].stop()
