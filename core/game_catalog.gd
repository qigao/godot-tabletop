class_name TabletopCatalog
extends RefCounted

const RULES = {"doudizhu": preload("res://games/doudizhu/rules.gd")}

static func games() -> Array[Dictionary]:
	return [{"id": "doudizhu", "title": "DouDiZhu", "seats": 3, "kind": "card"}]

static func create_rules(id: String) -> TabletopRules:
	return RULES[id].new()
