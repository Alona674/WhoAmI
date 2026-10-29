
class_name InteractionPrompt
extends Control

@onready var object_name_label: Label = $ObjectNameLabel
@onready var action_label: Label = $ActionLabel


func show_prompt(object_name: String, action_name: String) -> void:
	object_name_label.text = object_name
	action_label.text = "E — " + action_name
	show()


func hide_prompt() -> void:
	hide()


func position_above(screen_position: Vector2) -> void:
	size = get_combined_minimum_size()
	var viewport_rect := get_viewport_rect().grow(-12.0)
	var desired_position := screen_position - Vector2(size.x / 2.0, size.y + 12.0)
	position = desired_position.clamp(viewport_rect.position, viewport_rect.end - size)


func set_action_visible(is_visible: bool) -> void:
	action_label.visible = is_visible
