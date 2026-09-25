class_name UIKit
extends RefCounted
## Сборка интерфейса в коде по токенам DS: тексты, кнопки, контейнеры, отступы.


static func label(text: String, style: StringName = &"body", color: Color = UITokens.TEXT_PRIMARY, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIFonts.apply(l, style, color)
	return l


static func mono(text: String, color: Color = UITokens.TEXT_MUTED, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return label(text.to_upper(), &"label", color, align)


static func button(text: String, variant: GlowButton.Variant, action: Callable, disabled_reason: String = "") -> GlowButton:
	var b: GlowButton = GlowButton.new()
	b.variant = variant
	b.text = text
	b.disabled_reason = disabled_reason
	if action.is_valid():
		b.pressed.connect(action)
	return b


## Кнопка ▶ Rewarded: глиф, показ рекламы по плейсменту, авто-Disabled по лимиту и готовности.
static func ad_button(text: String, variant: GlowButton.Variant, placement: StringName) -> GlowButton:
	var b: GlowButton = button(text, variant, AdManager.show_rewarded.bind(placement))
	b.ad = true
	b.ad_placement = placement
	return b


static func vbox(separation: int = UITokens.S3, align: BoxContainer.AlignmentMode = BoxContainer.ALIGNMENT_BEGIN) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", separation)
	box.alignment = align
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


static func hbox(separation: int = UITokens.S2, align: BoxContainer.AlignmentMode = BoxContainer.ALIGNMENT_BEGIN) -> HBoxContainer:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override(&"separation", separation)
	box.alignment = align
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


static func spacer(vertical: bool = true) -> Control:
	var c: Control = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vertical:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func gap(height: float) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func panel(variation: StringName = &"PanelCard") -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.theme_type_variation = variation
	return p


## Корень экрана: фон ink.900, безопасная зона, боковые поля 20pt.
static func screen_root(owner: Control, background: Color = UITokens.INK_900) -> VBoxContainer:
	owner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = background
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(bg)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.side_margin = UITokens.S5
	owner.add_child(safe)
	var column: VBoxContainer = vbox(UITokens.S4)
	safe.add_child(column)
	return column


static func format_number(value: int) -> String:
	var digits: String = str(absi(value))
	var out: String = ""
	while digits.length() > 3:
		out = " " + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


static func format_time(seconds: float) -> String:
	var s: int = floori(seconds)
	return "%02d:%02d" % [floori(s / 60.0), s % 60]
