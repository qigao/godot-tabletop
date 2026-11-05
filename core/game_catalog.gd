class_name TabletopCatalog
extends RefCounted

const MODULES = {
	"doudizhu": preload("res://games/doudizhu/module.tres"),
	"gomoku": preload("res://games/gomoku/module.tres"),
}

static func games() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for module in MODULES.values():
		result.append({"id": module.id, "title": module.title, "seats": module.seat_count, "kind": module.kind})
	return result

static func create_rules(id: String) -> TabletopRules:
	return module_for(id).create_rules()

static func module_for(id: String) -> TabletopGameModule:
	return MODULES[id]

static func contains(id: String) -> bool:
	return MODULES.has(id)
