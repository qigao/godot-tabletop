class_name TabletopAudioCue
extends Resource

@export var id: String
@export var event_type: String
@export var fields: Dictionary = {}
@export var when: Dictionary = {"literal": true}
@export var stream: AudioStream
@export_enum("effect", "voice", "notice", "music") var channel: String = "effect"
@export var volume_db: float = -6.0
