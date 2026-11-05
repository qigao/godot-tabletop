class_name TabletopBinding
extends RefCounted
## Small value-only bindings, not executable scripts or a rules language.

static func read(spec: Variant, context: Dictionary) -> Variant:
	if spec is Array:
		var values: Array = []
		for item in spec:
			values.append(read(item, context))
		return values
	if not spec is Dictionary:
		return spec
	assert(spec.size() == 1, "A binding has exactly one operator")
	var op: String = spec.keys()[0]
	var argument: Variant = spec[op]
	match op:
		"get":
			var value: Variant = context
			for part in str(argument).split("."):
				value = value[part]
			return value
		"at":
			return read(argument[0], context)[read(argument[1], context)]
		"text": return str(read(argument, context))
		"format": return str(argument[0]) % read(argument.slice(1), context)
		"eq": return read(argument[0], context) == read(argument[1], context)
		"empty": return read(argument, context).is_empty()
		"if":
			return read(argument[1] if read(argument[0], context) else argument[2], context)
		"join":
			var parts := PackedStringArray()
			for value in read(argument[1], context):
				parts.append(str(value))
			return str(argument[0]).join(parts)
		"map":
			var mapped: Array = []
			for item in read(argument[0], context):
				var local := context.duplicate()
				local.item = item
				mapped.append(read(argument[1], local))
			return mapped
	assert(false, "Unknown presentation binding: " + op)
	return null
