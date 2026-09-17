extends Node2D


@onready var mama = $Mama
@onready var svetik = $Svetik
@onready var dialogue_manager = $DialogueManager


var scene_stage: int = 0


func _ready() -> void:
	mama.hide()
	svetik.hide()

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


func start_mama_scene() -> void:
	scene_stage = 2

	var target_position: Vector2 = mama.position

	# Мама начинает за дверью
	mama.position = target_position + Vector2(-500, 0)

	# Сначала дверь закрыта
	$DoorClosed.show()
	$DoorOpen.hide()

	mama.show()

	# Небольшая пауза перед открытием двери
	await get_tree().create_timer(0.5).timeout

	# Открываем дверь
	$DoorClosed.hide()
	$DoorOpen.show()

	# Мама выходит из двери
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

	# Небольшая пауза перед репликой
	await get_tree().create_timer(0.4).timeout

	dialogue_manager.show_dialogue(
		"Мама",
		"Михаил, просыпайся. Завтрак уже готов."
	)

func start_svetik_scene() -> void:
	scene_stage = 3

	# Мама резко разворачивается к двери
	var mama_sprite: Sprite2D = mama.get_node("Sprite2D")
	mama_sprite.scale.x = -mama_sprite.scale.x

	# Мама уходит обратно через дверь
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

	# После ухода мамы появляется Светик
	start_svetik_appearance()

func start_svetik_appearance() -> void:
	# Запоминаем обычное положение Светика
	var target_position: Vector2 = svetik.position

	# Светик появляется немного выше
	svetik.position = target_position + Vector2(0, -40)

	# Начинаем полностью прозрачным
	svetik.modulate.a = 0.0

	svetik.show()

	# Плавно появляется и опускается на своё место
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
