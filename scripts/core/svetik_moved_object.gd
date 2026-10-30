extends InteractableBase

func interact() -> void:
	var dialogue_manager = get_tree().current_scene.get_node_or_null("DialogueManager")
	if dialogue_manager != null:
		dialogue_manager.show_dialogue(
			interaction_name,
			"Этот предмет сюда перетащил Светик.",
			false
		)
