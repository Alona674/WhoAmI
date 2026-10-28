
extends Node2D

@onready var mama = $Mama
@onready var svetik = $Svetik
@onready var dialogue_manager = $DialogueManager
@onready var wardrobe_loot_panel = $UILayer/WardrobeLootPanel
@onready var mama_interactable = $Mama
@onready var svetik_interactable = $Svetik

var scene_stage: int = 0

var teddy_dialogue_active: bool = false
var teddy_dialogue_step: int = 0
var svetik_greeting_active: bool = false


func _ready() -> void:
	mama.hide()
	svetik.hide()

	mama_interactable.can_interact = false
	svetik_interactable.can_interact = false

	if not dialogue_manager.dialogue_closed.is_connected(_on_dialogue_closed):
		dialogue_manager.dialogue_closed.connect(_on_dialogue_closed)

	if not wardrobe_loot_panel.panel_closed.is_connected(_on_wardrobe_panel_closed):
		wardrobe_loot_panel.panel_closed.connect(_on_wardrobe_panel_closed)


# --------------------------------------------------
# ВЗАИМОДЕЙСТВИЕ С ТЕДДИ
# --------------------------------------------------

func teddy_interacted() -> void:
	if dialogue_manager.is_open:
		return

	if teddy_dialogue_active:
		return

	# До появления Светика — только реплика Михаила.
	# После появления Светика — полноценный диалог из трёх реплик.
	if scene_stage != 0 and scene_stage != 3:
		return

	teddy_dialogue_active = true
	teddy_dialogue_step = 0

	dialogue_manager.show_dialogue(
		"Михаил",
		"Это Тедди. Это мой друг, с ним весело играть в шахматы. Я всегда побеждаю!"
	)


# --------------------------------------------------
# ЗАВЕРШЕНИЕ ДИАЛОГОВ
# --------------------------------------------------

func _on_dialogue_closed() -> void:
	
	print("ДИАЛОГ ЗАКРЫТ")
	print("Этап: ", scene_stage)
	print("Диалог Тедди активен: ", teddy_dialogue_active)
	print("Шаг диалога: ", teddy_dialogue_step)

	# Диалог о Тедди после появления Светика.
	if teddy_dialogue_active:
		if scene_stage == 3:
			if teddy_dialogue_step == 0:
				print("ЗАПУСКАЕМ РЕПЛИКУ СВЕТИКА")
				teddy_dialogue_step = 1

				dialogue_manager.show_dialogue(
					"Светик",
					"Ха, какая рухлядь. Миша, тебе стоит завести новых друзей."
				)
				return

			if teddy_dialogue_step == 1:
				teddy_dialogue_step = 2

				dialogue_manager.show_dialogue(
					"Михаил",
					"Но ведь мы с ним с самого детства."
				)
				return

		teddy_dialogue_active = false
		teddy_dialogue_step = 0
		return

	# Приветствие Светика завершилось.
	if svetik_greeting_active:
		svetik_greeting_active = false
		return

	# Первая реплика Тедди завершилась до появления Светика.
	if scene_stage == 1:
		return

	# Диалог мамы завершился — запускаем появление Светика.
	if scene_stage == 2:
		start_svetik_scene()


# --------------------------------------------------
# ЗАКРЫТИЕ ШКАФА
# --------------------------------------------------

func _on_wardrobe_panel_closed() -> void:
	print("Шкаф закрыт. Этап сюжета: ", scene_stage)

	if scene_stage >= 2:
		return

	start_mama_scene()


# --------------------------------------------------
# ПОЯВЛЕНИЕ МАМЫ
# --------------------------------------------------

func start_mama_scene() -> void:
	scene_stage = 2

	var target_position: Vector2 = mama.position
	mama.position = target_position + Vector2(-500, 0)

	$DoorOpen2.show()
	$"Dver(2)".show()

	mama.show()
	mama_interactable.can_interact = true

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


# --------------------------------------------------
# УХОД МАМЫ
# --------------------------------------------------

func start_svetik_scene() -> void:
	if scene_stage != 2:
		return

	scene_stage = 3

	mama_interactable.can_interact = false

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


# --------------------------------------------------
# ПОЯВЛЕНИЕ СВЕТИКА
# --------------------------------------------------

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

	svetik_interactable.can_interact = true
	svetik.start_follow($Player)

	await get_tree().create_timer(0.3).timeout

	svetik_greeting_active = true

	dialogue_manager.show_dialogue(
		"Светик",
		"Доброе утро, Михаил."
	)


# --------------------------------------------------
# ПАУЗА
# --------------------------------------------------

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
