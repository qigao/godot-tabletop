class_name TabletopCuePlayer
extends Node
## Foreground announcements follow live tokens; music is a separate local stream.

signal cue_started(id: String)
var media: TabletopMediaPack
var muted := false:
	set(value):
		muted = value
		if muted:
			stop()
		elif is_inside_tree() and not _suspended:
			_ensure_music(media.background_music, media.music_volume_db)
var _last_token := -1
var _suspended := false
var _players: Dictionary = {}
var _queues: Dictionary = {"effect": [], "voice": [], "notice": []}

func _ready() -> void:
	for channel in _queues:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players[channel] = player
		player.finished.connect(_next.bind(channel))
	var music := AudioStreamPlayer.new()
	add_child(music)
	_players.music = music

func present(frame: Dictionary) -> void:
	_suspended = frame.paused
	_players.music.stream_paused = _suspended
	if not muted and not _suspended:
		if frame.transition in ["created", "reset", "review", "import", "switch"]:
			_ensure_music(media.background_music, media.music_volume_db)
		elif not _players.music.playing:
			_ensure_music(media.background_music, media.music_volume_db)
	if frame.token == _last_token:
		return
	_last_token = frame.token
	_stop_foreground()
	if frame.events.is_empty() or frame.paused or muted:
		return
	for event in frame.events:
		var context := {"event": event, "observation": frame.observation}
		for cue in media.cues:
			if cue.event_type != event.type:
				continue
			var matches := bool(TabletopBinding.read(cue.when, context))
			for key in cue.fields:
				if TabletopBinding.read({"get": "event." + key}, context) != cue.fields[key]:
					matches = false
			if matches:
				if cue.channel == "music":
					_ensure_music(cue.stream, cue.volume_db)
					cue_started.emit(cue.id)
				else:
					_queues[cue.channel].append(cue)
	for channel in _queues:
		_next(channel)

func _ensure_music(stream: AudioStream, volume: float) -> void:
	if stream == null:
		return
	var player: AudioStreamPlayer = _players.music
	if player.stream == stream and player.playing:
		return
	player.stream = stream
	player.volume_db = volume
	player.play()

func _next(channel: String) -> void:
	if _queues[channel].is_empty():
		return
	var cue: TabletopAudioCue = _queues[channel].pop_front()
	var player: AudioStreamPlayer = _players[channel]
	player.stream = cue.stream
	player.volume_db = cue.volume_db
	player.play()
	cue_started.emit(cue.id)

func _stop_foreground() -> void:
	for channel in _queues:
		_queues[channel].clear()
		_players[channel].stop()

func stop() -> void:
	_stop_foreground()
	_players.music.stop()
