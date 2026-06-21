extends Panel

const CLICK_SFX = preload("res://src/assets/audio/click_001.ogg")

@export() var rewarded: int = 10

@onready var reward_button: Button = %RewardButton
@onready var hidden_leave_button: Button = %HiddenLeaveButton
@onready var soft_currency: SoftCurrency = %SoftCurrency

func _ready() -> void:
	hidden_leave_button.show()
	soft_currency.set_amount(0)
	
	AdManager.reward_earned.connect(_on_reward_earned)
	hidden_leave_button.pressed.connect(_on_hidden_leave_button_pressed)
	reward_button.pressed.connect(_on_reward_button_pressed)
	self.visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	soft_currency.set_amount(rewarded)

func _on_hidden_leave_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	GameManager.go_to_main_menu()

func _on_reward_button_pressed() -> void:
	reward_button.hide()
	AdManager.show_rewarded_ad()

func _on_reward_earned() -> void:
	# Add reward x2, first x1 was add when game finihsed
	# Here just second part after reward
	GameManager.add_sparks(rewarded)
	soft_currency.set_amount(rewarded * 2)
	GameManager.go_to_main_menu()
