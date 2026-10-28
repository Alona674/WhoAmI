
extends Node2D

@onready var player = $Player
@onready var mama = $Mama
@onready var svetik = $Svetik
@onready var dialogue_manager = $DialogueManager

var scene_stage: int = 0


func _ready() -> void:
	mama.hide()
	svetik.hide()

	# Восстанавливаем состояние спальни,
	# если вступительные диалоги уже завершены
	if GameState.bedroom_intro_completed:
		scene_stage = 3
		svetik.show()
		$DoorClosed.hide()
		$DoorOpen.show()

	# Перемещаем Михаила к нужной точке появления
	if GameState.next_spawn_point != "":
		var spawn_point = get_node_or_null(GameState.next_spawn_point)

		if spawn_point != null:
			player.global_position = spawn_point.global_position
		else:
			push_warning(
				"Не найдена точка появления: "
				+ GameState.next_spawn_point
			)

		GameState.next_spawn_point = ""

	dialogue_manager.dialogue_closed.connect(_on_dialogue_closed)


func teddy_interacted() -> void:
	if scene_stage != 0:
		return

	scene_stage = 1

	dialogue_manager.show_dialogue(
		"Михаил",
		"Это мой старый Тедди."
	)


func _on_dialogue_closed() -> void:
	if scene_stage == 1:
		start_mama_scene()
		return

	if scene_stage == 2:
		start_svetik_scene()
		return

	if scene_stage == 3:
		GameState.bedroom_intro_completed = true


func start_mama_scene() -> void:
	scene_stage = 2

	var target_position: Vector2 = mama.position

	mama.position = target_position + Vector2(-500, 0)

	$DoorClosed.show()
	$DoorOpen.hide()

	mama.show()

	await get_tree().create_timer(0.5).timeout

	$DoorClosed.hide()
	$DoorOpen.show()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		mama,
		"position",
		target_position,
		1.5
	)

	await tween.finished

	await get_tree().create_timer(0.4).timeout

	dialogue_manager.show_dialogue(
		"Мама",
		"Михаил, просыпайся. Завтрак уже готов."
	)


func start_svetik_scene() -> void:
	scene_stage = 3

	var mama_sprite: Sprite2D = mama.get_node("Sprite2D")

	mama_sprite.scale.x = -mama_sprite.scale.x

	var mama_exit_position: Vector2 = mama.position + Vector2(-500, 0)

	var mama_tween := create_tween()
	mama_tween.set_trans(Tween.TRANS_SINE)
	mama_tween.set_ease(Tween.EASE_IN_OUT)

	mama_tween.tween_property(
		mama,
		"position",
		mama_exit_position,
		1.5
	)

	await mama_tween.finished

	mama.hide()

	start_svetik_appearance()


func start_svetik_appearance() -> void:
	var target_position: Vector2 = svetik.position

	svetik.position = target_position + Vector2(0, -40)
	svetik.modulate.a = 0.0

	svetik.show()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(
		svetik,
		"modulate:a",
		1.0,
		1.2
	)

	tween.parallel().tween_property(
		svetik,
		"position",
		target_position,
		1.2
	)

	await tween.finished

	await get_tree().create_timer(0.3).timeout

	dialogue_manager.show_dialogue(
		"Светик",
		"Доброе утро, Михаил."
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		var pause_menu = get_node_or_null("UILayer/PauseMenu")

		if pause_menu == null:
			return

		pause_menu.visible = not pause_menu.visible
		get_tree().paused = pause_menu.visible

		get_viewport().set_input_as_handled()


func _on_continuebutton_pressed() -> void:
	get_tree().paused = false

	var pause_menu = get_node_or_null("UILayer/PauseMenu")

	if pause_menu != null:
		pause_menu.visible = false
