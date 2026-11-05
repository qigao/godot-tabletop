@abstract
class_name TabletopGameView
extends Control
## Views render frames and request commands. They never own a live rules session.

signal command_requested(command: Dictionary, token: int)
signal lifecycle_requested(action: String, token: int)

var frame_token: int = 0
var blocked: bool = false
var configuration: TabletopPresentation
var cues: TabletopCuePlayer
var client_frame: Dictionary
var reduced_motion := false

func _ready() -> void:
	cues = TabletopCuePlayer.new()
	cues.media = configuration.media
	add_child(cues)

func present(frame: Dictionary) -> void:
	client_frame = frame
	frame_token = frame.token
	blocked = frame.paused
	render(frame.observation, frame.legal_actions)
	cues.present(frame)

func binding_context(observation: Dictionary) -> Dictionary:
	return {"observation": observation, "assets": {"cards": configuration.media.cards}}

func request_command(command: Dictionary) -> void:
	command_requested.emit(command, frame_token)

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value

func capture_ui_state() -> Dictionary:
	return {}

func restore_ui_state(_state: Dictionary) -> void:
	pass

@abstract func render(observation: Dictionary, legal: Array[Dictionary]) -> void
@abstract func deactivate() -> void
