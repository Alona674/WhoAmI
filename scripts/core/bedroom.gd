extends Node2D
@onready var player = $Player
@onready var mama = $Mama
@onready var svetik = $Svetik
@onready var dialogue_manager = $DialogueManager
@onready var prompt: Label = $UILayer/InteractionPrompt
var scene_stage: int = 0
var busy: bool = false

func _ready() -> void:
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
		prompt.text = "E — В коридор"
	elif player.current_interactable != null:
		match player.current_interactable.name:
			"Wardrobe":
				prompt.text = "E — Открыть шкаф"
			"Teddy":
				prompt.text = "E — Осмотреть Тедди"
			"Mama":
				prompt.text = "E — Поговорить с мамой"
			"Svetik":
				prompt.text = "E — Поговорить со Светиком"
			_:
				prompt.text = "E — " + player.current_interactable.interaction_name
	else:
		prompt.hide()
		return
	prompt.show()

func say(speaker: String, words: String) -> void:
	dialogue_manager.show_dialogue(speaker, words)
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
	mama.position = Vector2(100, 706)
	mama.show()
	mama.get_node("Sprite2D").flip_h = false
	var arrival = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await arrival.tween_property(mama, "position", Vector2(750, 706), 1.5).finished
	await get_tree().create_timer(0.4).timeout
	await say("Мама", "Михаил, просыпайся. Завтрак уже готов.")
	player.can_move = false
	mama.get_node("Sprite2D").flip_h = true
	var departure = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await departure.tween_property(mama, "position", Vector2(100, 706), 1.5).finished
	mama.hide()
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
