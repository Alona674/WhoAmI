extends Node2D
@onready var player = $Player
@onready var mama = $Mama
@onready var svetik = $Svetik
@onready var dialogue_manager = $DialogueManager
@onready var prompt: InteractionPrompt = $UILayer/InteractionPrompt
var scene_stage: int = 0
var busy: bool = false

func _ready() -> void:
	SvetikWorld.restore_room(self)
	mama.hide()
	svetik.visible = GameState.bedroom_intro_completed
	scene_stage = 3 if GameState.bedroom_intro_completed else 0
	if GameState.next_spawn_point != "":
		var spawn = get_node_or_null(GameState.next_spawn_point)
		if spawn != null:
			player.global_position = spawn.global_position
		GameState.next_spawn_point = ""

func _process(_delta: float) -> void:
	if busy or not player.can_move or $UILayer/ContainerPanel.visible or $UILayer/PauseMenu.visible or $UILayer/WindowView.visible:
		prompt.hide()
		return
	if $CorridorDoor.player_nearby:
		player.show_interaction_prompt($CorridorDoor, "Коридор", "Войти")
	elif player.current_interactable != null:
		match player.current_interactable.name:
			"Wardrobe":
				player.show_interaction_prompt(player.current_interactable, "Шкаф", "Открыть")
			"Teddy":
				player.show_interaction_prompt(player.current_interactable, "Тедди", "Осмотреть")
			"Mama":
				player.show_interaction_prompt(player.current_interactable, "Мама", "Поговорить")
			"Svetik":
				player.show_interaction_prompt(player.current_interactable, "Светик", "Поговорить")
			"WindowArea":
				player.show_interaction_prompt(player.current_interactable, "Окно", "Посмотреть")
			_:
				player.show_interaction_prompt(player.current_interactable)
	else:
		prompt.hide()
		return

func say(speaker: String, words: String) -> void:
	dialogue_manager.show_dialogue(speaker, words, speaker == "Светик")
	await dialogue_manager.dialogue_closed

func teddy_interacted() -> void:
	if busy:
		return
	busy = true
	await say("Михаил", "Это Тедди. Это мой друг, с ним весело играть в шахматы. Я всегда побеждаю!")
	if scene_stage == 3:
		await say("Светик", "Ха, какая рухлядь. Миша, тебе стоит завести новых друзей.")
		await say("Михаил", "Но ведь мы с ним с самого детства.")
		GameState.add_item("teddy")
	busy = false
	player.can_move = true

func wardrobe_closed() -> void:
	if busy or scene_stage >= 2:
		return
	busy = true
	scene_stage = 2
	player.can_move = false
	$DoorOpen.show()
	var entrance_x := -250.0
	var floor_y: float = player.floor_y
	mama.position = Vector2(entrance_x, floor_y)
	mama.modulate.a = 0.0
	var mama_sprite: Sprite2D = mama.get_node("Sprite2D")
	mama_sprite.flip_h = false
	mama.show()
	var arrival = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	arrival.parallel().tween_property(mama, "modulate:a", 1.0, 0.45).set_delay(0.15)
	await arrival.tween_property(mama, "position", Vector2(750, floor_y), 2.0).finished
	await get_tree().create_timer(0.4).timeout
	await say("Мама", "Михаил, просыпайся. Завтрак уже готов.")
	player.can_move = false
	mama_sprite.flip_h = true
	var departure = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	departure.parallel().tween_property(mama, "modulate:a", 0.0, 0.45).set_delay(0.25)
	await departure.tween_property(mama, "position", Vector2(entrance_x, floor_y), 0.85).finished
	mama.hide()
	mama.modulate.a = 1.0
	$DoorOpen.hide()
	var target_position: Vector2 = svetik.position
	svetik.position = target_position + Vector2(0, -40)
	svetik.modulate.a = 0.0
	svetik.show()
	var appearance = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	appearance.parallel().tween_property(svetik, "modulate:a", 1.0, 1.2)
	appearance.parallel().tween_property(svetik, "position", target_position, 1.2)
	await appearance.finished
	await get_tree().create_timer(0.3).timeout
	await say("Светик", "Доброе утро, Михаил.")
	GameState.bedroom_intro_completed = true
	svetik.start_following()
	scene_stage = 3
	busy = false
	player.can_move = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		prompt.hide()
		$UILayer/PauseMenu.show()
		get_tree().paused = true
		get_viewport().set_input_as_handled()
