extends Panel

const CLICK_SFX = preload("res://src/assets/audio/click_001.ogg")

@onready var revive_button: Button = %ReviveButton
@onready var leave_button: Button = %LeaveButton
@onready var hidden_leave_button: Button = %HiddenLeaveButton
@onready var cooldown_rogress: TextureProgressBar = %CooldownProgress
@onready var cooldown_label: Label = %Cooldown
@onready var revive_label: Label = %Revive

var progress_timer: Timer
var progress_count: int = 5
const progress_count_step: int = 1

func _ready() -> void:
	hidden_leave_button.hide()
	cooldown_label.text = " " + str(progress_count)

	progress_timer = Timer.new()
	self.add_child(progress_timer)

	progress_timer.timeout.connect(_on_progress_timer_timeout)
	revive_button.pressed.connect(_on_revive_button_pressed)
	hidden_leave_button.pressed.connect(_on_hidden_leave_button_pressed)
	leave_button.pressed.connect(_on_leave_button_pressed)

	self.visibility_changed.connect(_on_visibility_changed)

func start_cooldown() -> void:
		cooldown_label.show()
		revive_label.show()
		revive_button.show()
		hidden_leave_button.hide()

		leave_button.text = "No thaanks"

		progress_timer.start(1.0)

func _on_progress_timer_timeout() -> void:
	progress_count -= progress_count_step
	
	if progress_count <= 0:
		progress_timer.stop()
		
		cooldown_label.hide()
		revive_label.hide()
		revive_button.hide()
		hidden_leave_button.show()
		
		leave_button.text = "Tap anywhere to continue"
		return
	
	cooldown_rogress.value = progress_count
	cooldown_label.text = " " + str(progress_count)

func _on_visibility_changed() -> void:
	if visible:
		start_cooldown() 

func _on_revive_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	revive_button.hide()
	AdManager.show_rewarded_ad()

func _on_hidden_leave_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	GameManager.go_to_main_menu()

func _on_leave_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	GameManager.go_to_main_menu()
