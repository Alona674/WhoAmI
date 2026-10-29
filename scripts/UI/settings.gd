extends Control

var opened_from_pause: bool = false

@onready var interaction_hints_button: CheckButton = $CenterContainer/VBoxContainer/InteractionHintsButton
func _ready() -> void:
	interaction_hints_button.button_pressed = GameState.interaction_hints_enabled
	interaction_hints_button.toggled.connect(_on_interaction_hints_button_toggled)


func _on_interaction_hints_button_toggled(toggled_on: bool) -> void:
	GameState.interaction_hints_enabled = toggled_on
	print("Подсказки включены: ", GameState.interaction_hints_enabled)

func _on_back_button_pressed() -> void:
	if opened_from_pause:
		queue_free()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if opened_from_pause:
			queue_free()
		else:
			get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
