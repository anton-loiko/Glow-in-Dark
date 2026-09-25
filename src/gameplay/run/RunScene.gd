class_name RunScene
extends Node2D
## Сцена забега S05: собирает мир, игрока, пикапы, камеру и директора для GameManager.current_run.
## Экраном её открывает SceneRouter; RunContext создан заранее в GameManager.start_run().

@export var chapter_environment: ChapterEnvironment
@export var streamer: ChunkStreamer
@export var pickups: PickupSystem
@export var player: Player
@export var camera: RunCamera
@export var burst: LightBurst
@export var fx_layer: Node2D
@export var director: RunDirector
@export var enemies: EnemyManager
@export var waves: WaveDirector
@export var skills: SkillHost


func _ready() -> void:
	set_process(false)


func on_screen_enter(_params: Dictionary) -> void:
	var run: RunContext = GameManager.current_run
	if run == null:
		push_error("[RunScene] opened without an active run")
		return
	var balance: Dictionary = ConfigDB.get_balance()
	var chapter: ChapterDef = ConfigDB.get_chapter(run.chapter_id)
	var skin: SkinDef = ConfigDB.get_skin(GameManager.profile.skin_equipped)
	chapter_environment.setup(chapter)
	player.setup(run.stats, balance, skin)
	camera.setup(balance)
	pickups.setup(player, balance)
	streamer.setup(player, chapter, run.run_seed, balance)
	var fog: FogLayer = FogLayer.new()
	fog.setup(camera, chapter.palette_color("fog", Color("#4C5C7A")), float(chapter.palette.get("fog_density", 0.16)))
	streamer.add_sibling(fog)
	burst.setup(balance)
	director.setup(run, chapter, balance)
	enemies.setup(player, pickups, streamer, camera, run)
	waves.setup(run, enemies, pickups, streamer, player, camera)
	skills.setup(player, enemies, pickups, camera, run)
	DamagePool.bind_world(fx_layer)
	var particles: ParticleFx = ParticleFx.new()
	particles.light_color = skin.light_color if skin != null else UITokens.LIGHT_500
	fx_layer.add_child(particles)
	if PerfOverlay.is_allowed():
		var overlay: PerfOverlay = PerfOverlay.new()
		overlay.enemies = enemies
		overlay.pickups = pickups
		overlay.run = run
		add_child(overlay)


func _exit_tree() -> void:
	DamagePool.unbind()
