class_name TabletopGameModule
extends Resource
## A rules adapter and a Godot view are registered together, outside the host.

@export var id: String
@export var title: String
@export var kind: String
@export var seat_count: int
@export var rules_script: Script
@export var view_scene: PackedScene

func create_rules() -> TabletopRules:
	return rules_script.new()

func create_view() -> TabletopGameView:
	return view_scene.instantiate() as TabletopGameView
