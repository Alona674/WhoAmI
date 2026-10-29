extends Control


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_tree().paused = false
		hide()
		get_viewport().set_input_as_handled()


func _on_continue_button_pressed() -> void:
	get_tree().paused = false
	hide()

func _on_save_button_pressed() -> void:
	var save_menu = load("res://scenes/ui/savedzone.tscn").instantiate()
	add_child(save_menu)


func _on_load_button_pressed() -> void:
	var load_menu = load("res://scenes/ui/loadzone.tscn").instantiate()
	add_child(load_menu)


func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _on_exit_button_pressed() -> void:
	get_tree().quit()
