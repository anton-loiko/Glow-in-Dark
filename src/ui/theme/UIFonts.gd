class_name UIFonts
extends RefCounted
## Типографика DS §01: Unbounded — заголовки, числа, кнопки; Manrope — текст; JetBrains Mono — метки.
## Пиксельные шрифты не используются нигде.

const UNBOUNDED: FontFile = preload("res://src/ui/theme/fonts/Unbounded-Variable.ttf")
const MANROPE: FontFile = preload("res://src/ui/theme/fonts/Manrope-Variable.ttf")
const MONO: FontFile = preload("res://src/ui/theme/fonts/JetBrainsMono-Variable.ttf")

## Стиль → [шрифт, вес, размер].
const STYLES: Dictionary = {
	&"display": ["unbounded", 800, 34],
	&"h1": ["unbounded", 800, 24],
	&"h2": ["unbounded", 600, 18],
	&"button": ["unbounded", 800, 16],
	&"number": ["unbounded", 600, 14],
	&"body": ["manrope", 500, 15],
	&"body_s": ["manrope", 500, 13],
	&"quiet": ["manrope", 700, 14],
	&"label": ["mono", 600, 11],
}

static var _cache: Dictionary = {}


static func font(style: StringName) -> FontVariation:
	if _cache.has(style):
		return _cache[style]
	var spec: Array = STYLES.get(style, STYLES[&"body"])
	var variation: FontVariation = FontVariation.new()
	match str(spec[0]):
		"unbounded":
			variation.base_font = UNBOUNDED
		"mono":
			variation.base_font = MONO
		_:
			variation.base_font = MANROPE
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): int(spec[1])}
	if style == &"number":
		variation.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"): 1}
	if style == &"label":
		variation.spacing_glyph = 2
	_cache[style] = variation
	return variation


static func size(style: StringName) -> int:
	return int((STYLES.get(style, STYLES[&"body"]) as Array)[2])


## Применить стиль к Label/Button.
static func apply(control: Control, style: StringName, color: Color = UITokens.TEXT_PRIMARY, font_size: int = 0) -> void:
	control.add_theme_font_override(&"font", font(style))
	control.add_theme_font_size_override(&"font_size", font_size if font_size > 0 else size(style))
	control.add_theme_color_override(&"font_color", color)
