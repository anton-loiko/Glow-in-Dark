class_name DefUtil
extends RefCounted
## Общие преобразования для Def-классов.


static func to_string_names(values: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if values is Array:
		for v: Variant in values:
			result.append(StringName(str(v)))
	return result


static func color_or(value: Variant, fallback: Color) -> Color:
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback
