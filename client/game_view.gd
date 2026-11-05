@abstract
class_name TabletopGameView
extends Control
## Views render frames and request commands. They never own a live rules session.

signal command_requested(command: Dictionary, token: int)

var frame_token: int = 0
var blocked: bool = false

func present(frame: Dictionary) -> void:
	frame_token = frame.token
	blocked = frame.paused
	render(frame.observation, frame.legal_actions)

func request_command(command: Dictionary) -> void:
	command_requested.emit(command, frame_token)

@abstract func render(observation: Dictionary, legal: Array[Dictionary]) -> void
@abstract func deactivate() -> void
