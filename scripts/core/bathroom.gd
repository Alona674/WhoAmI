extends Node2D

@onready var player = $Player
@onready var dialogue_manager = $DialogueManager
@onready var pause_menu = $UILayer/PauseMenu
@onready var prompt: Label = $UILayer/InteractionPrompt


func _ready() -> void:
	if GameState.next_spawn_point != "":
		var spawn_point = get_node_or_null(GameState.next_spawn_point)
		if spawn_point != null:
			player.global_position = spawn_point.global_position
		GameState.next_spawn_point = ""


func _process(_delta: float) -> void:
	if dialogue_manager.dialogue_box.visible or pause_menu.visible:
		prompt.hide()
	elif $CorridorDoor.player_nearby:
		prompt.text = "E — В коридор"
		prompt.show()
	elif player.current_interactable != null:
		prompt.text = "E — " + player.current_interactable.interaction_name
		prompt.show()
	else:
		prompt.hide()


func interact_item(item_id: String) -> void:
	# E also advances dialogue; don't restart it or act during its fade-out.
	if dialogue_manager.dialogue_box.visible:
		return

	var text: String = ""
	match item_id:
		"sink":
			if GameState.get_flag("bathroom_washed"):
				text = "Я уже умылся. Теперь бы не забыть про завтрак."
			else:
				GameState.set_flag("bathroom_washed")
				text = "Умоюсь прохладной водой. Вот теперь я окончательно проснулся."
		"mirror":
			if GameState.get_flag("bathroom_washed"):
				text = "Ну вот, теперь на меня смотрит вполне проснувшийся Михаил. Можно идти завтракать."
			else:
				text = "Это я. Только ещё немного сонный. Надо умыться."
	if not text.is_empty():
		dialogue_manager.show_dialogue("Михаил", text)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		pause_menu.visible = not pause_menu.visible
		get_tree().paused = pause_menu.visible
		get_viewport().set_input_as_handled()
