class_name StarterPackCard
extends PanelContainer
## Стартер-пак (DS S10, D18): двухцветная рамка «золото → кристалл», живой Лунный Огонёк освещает карточку,
## бейдж-таймер FOMO (24 ч от первого показа). Первый показ запускает таймер; по истечении карточка скрывается.

var _timer_label: Label
var _buy: GlowButton
var _tick_s: float = 0.0


func _ready() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = UITokens.INK_700
	style.set_corner_radius_all(UITokens.R16)
	style.set_content_margin_all(UITokens.S4)
	add_theme_stylebox_override(&"panel", style)
	draw.connect(_draw_frame)
	var row: HBoxContainer = UIKit.hbox(UITokens.S3)
	add_child(row)
	var moon: SkinDef = ConfigDB.get_skin(&"moon")
	var hero: HeroGlyph = HeroGlyph.new()
	hero.color = moon.light_color if moon != null else UITokens.CRYSTAL_300
	hero.diameter = 44.0
	hero.glow = UITokens.G2
	hero.custom_minimum_size = Vector2(84, 96)
	row.add_child(hero)
	var box: VBoxContainer = UIKit.vbox(UITokens.S1)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	var head: HBoxContainer = UIKit.hbox(UITokens.S2)
	box.add_child(head)
	var once: Label = UIKit.mono(tr("Только один раз"), UITokens.GOLD_300)
	once.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(once)
	_timer_label = UIKit.mono("", UITokens.THREAT)
	head.add_child(_timer_label)
	box.add_child(UIKit.label(tr("Набор Первого Света"), &"h2"))
	var desc: Label = UIKit.label(tr("Лунный Огонёк · класс «Ритм» + 500 ◆"), &"body_s", UITokens.TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)
	_buy = UIKit.button("", GlowButton.Variant.CRYSTAL, StoreManager.purchase.bind(&"starter_pack"))
	box.add_child(_buy)
	StoreManager.note_starter_pack_shown()
	refresh()


func _process(delta: float) -> void:
	_tick_s -= delta
	if _tick_s <= 0.0:
		_tick_s = 1.0
		refresh()


func refresh() -> void:
	if not StoreManager.starter_pack_active():
		visible = false
		set_process(false)
		return
	var left: int = StoreManager.starter_pack_seconds_left()
	_timer_label.text = "%02d:%02d:%02d" % [floori(left / 3600.0), floori((left % 3600) / 60.0), left % 60] if left > 0 else ""
	var price: String = StoreManager.price_label(&"starter_pack")
	_buy.set_label(price if not price.is_empty() else "…")
	_buy.set_blocked(price.is_empty(), tr("Магазин недоступен"))


## Рамка: верх — золото, низ — кристалл (двухцветный градиент по сторонам).
func _draw_frame() -> void:
	var r: Rect2 = Rect2(Vector2.ONE, size - Vector2.ONE * 2.0)
	var steps: int = 24
	for i: int in steps:
		var t0: float = float(i) / steps
		var t1: float = float(i + 1) / steps
		var c: Color = UITokens.GOLD_300.lerp(UITokens.CRYSTAL_500, t0)
		draw_line(Vector2(r.position.x, r.position.y + r.size.y * t0), Vector2(r.position.x, r.position.y + r.size.y * t1), c, 1.5)
		draw_line(Vector2(r.end.x, r.position.y + r.size.y * t0), Vector2(r.end.x, r.position.y + r.size.y * t1), c, 1.5)
	draw_line(r.position, Vector2(r.end.x, r.position.y), UITokens.GOLD_300, 1.5)
	draw_line(Vector2(r.position.x, r.end.y), r.end, UITokens.CRYSTAL_500, 1.5)
