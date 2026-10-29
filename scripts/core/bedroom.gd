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
	if busy or not player.can_move or $UILayer/ContainerPanel.visible or $UILayer/PauseMenu.visible:
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
	if scene_stage == 3:
		GameState.add_item("teddy")
		dialogue_manager.show_dialogue("Михаил", "Мой старый Тедди. Возьму его с собой.")
		return
	busy = true
	scene_stage = 1
	await say("Михаил", "Это мой старый Тедди.")
	player.can_move = false
	mama.position = Vector2(100, 706)
	mama.show()
	mama.get_node("Sprite2D").flip_h = false
	await create_tween().tween_property(mama,"position",Vector2(750,706),1.5).finished
	scene_stage = 2
	await say("Мама", "Михаил, просыпайся. Завтрак уже готов.")
	player.can_move = false
	mama.get_node("Sprite2D").flip_h = true
	await create_tween().tween_property(mama,"position",Vector2(100,706),1.5).finished
	mama.hide()
	svetik.modulate.a = 0.0
	svetik.show()
	await create_tween().tween_property(svetik,"modulate:a",1.0,0.6).finished
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
