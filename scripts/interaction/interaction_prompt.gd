
extends Control

@onready var object_name_label: Label = $ObjectNameLabel
@onready var action_label: Label = $ActionLabel


func show_prompt(object_name: String, action_name: String) -> void:
	print("ObjectNameLabel: ", object_name_label)
	print("ActionLabel: ", action_label)

	object_name_label.text = object_name
	action_label.text = "E — " + action_name
	show()


func hide_prompt() -> void:
	hide()


func set_action_visible(is_visible: bool) -> void:
	action_label.visible = is_visible
