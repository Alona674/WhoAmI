extends Node2D

var busy: bool = false

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
	if dialogue_manager.dialogue_box.visible or pause_menu.visible or $UILayer/ContainerPanel.visible:
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
	if busy or dialogue_manager.dialogue_box.visible:
		return

	if item_id == "mirror" and not GameState.get_flag("bathroom_mirror_completed"):
		play_mirror_scene()
		return
	if item_id == "basket":
		inspect_basket()
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


func say(speaker: String, words: String) -> void:
	dialogue_manager.show_dialogue(speaker, words)
	await dialogue_manager.dialogue_closed


func play_mirror_scene() -> void:
	busy = true
	await say("Михаил", "Ух ты, я как всегда выгляжу круто!")
	$MirrorGlass/Reflection.material.set_shader_parameter("blood", true)
	$Svetik.show()
	await say("Светик", "А так?")
	await say("Михаил", "Аааа, убери!!!")
	await say("Светик", "А мне кажется тебе так больше идёт.")
	$MirrorGlass/Reflection.material.set_shader_parameter("blood", false)
	await say("Михаил", "Фух, вроде всё на месте, я опять красавчик.")
	$Svetik.hide()
	GameState.set_flag("bathroom_mirror_completed")
	busy = false
	player.can_move = true


func inspect_basket() -> void:
	busy = true
	if GameState.get_flag("bathroom_sock_taken"):
		await say("Михаил", "Только грязное бельё. Носок я уже забрал.")
	else:
		await say("Михаил", "Фу, зачем я туда заглянул.")
		$UILayer/ContainerPanel.open_container("Корзина с грязным бельём", [{
			"id": "dirty_sock",
			"name": "Грязный носок",
			"texture": preload("res://art/items/bathroom/dirty_sock.png")
		}])
		await $UILayer/ContainerPanel.closed
		if GameState.has_item("dirty_sock"):
			GameState.set_flag("bathroom_sock_taken")
			await say("Михаил", "Это войдёт в мои сокровища. Кто знает, когда это может пригодиться.")
	busy = false
	player.can_move = true
