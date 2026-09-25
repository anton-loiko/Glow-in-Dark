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
	burst.setup(balance)
	director.setup(run, chapter, balance)
	DamagePool.bind_world(fx_layer)


func _exit_tree() -> void:
	DamagePool.unbind()
