class_name ChapterEnvironment
extends Node
## Окружение главы (task_2 §8): тьма вне света (CanvasModulate), bloom (WorldEnvironment glow,
## один проход — DS §08). Туман с параллаксом и реакция на фазы волн — task_3/task_8.

@export var canvas_modulate: CanvasModulate
@export var world_environment: WorldEnvironment


func setup(chapter: ChapterDef) -> void:
	canvas_modulate.color = chapter.palette_color("darkness", Color("#10141F"))
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 0.8
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	world_environment.environment = env
