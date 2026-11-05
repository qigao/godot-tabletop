class_name TabletopMediaPack
extends Resource
## Optional artwork and cue lists are explicit presentation features.

@export var table_texture: Texture2D
@export var card_face: Texture2D
@export var card_artwork: Dictionary = {}
@export var cards: Dictionary = {}
@export var pieces: Dictionary = {}
@export var cues: Array[TabletopAudioCue] = []
