class_name SkillsCardThumb
extends Control

@onready var label_count: Label = %LabelCount
@onready var icon: TextureRect = %Icon
@onready var v_box: VBoxContainer = $VBoxContainer
@onready var stars_container: HBoxContainer = %StarsContainer

func _ready() -> void:
	stars_container.hide()
	
	v_box.size_flags_horizontal = Control.SIZE_FILL
	v_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

func setup(skill_data: Dictionary, active_skill: Dictionary) -> void:
	if skill_data["icon"]:
		icon.texture = load(skill_data["icon"])
 
	var count = active_skill["count"]
	var max_count = skill_data["max"]
	if count:
		if count > 1:
			label_count.text = "x" + str(active_skill.count)
	
		if max_count > 0:
			# TODO: Create stars component
			stars_container.show()
			$VBoxContainer/StarsContainer/Label.text = str(active_skill.count) + "/" + str(max_count)
