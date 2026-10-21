extends Control


func _on_startbutton_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/rooms/bedroom.tscn")
	
func _on_endbutton_pressed() -> void:
	get_tree().quit()


func _on_settingsbutton_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/Settings.tscn")
