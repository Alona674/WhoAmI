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
		"Тедди",
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

	mama.show()

	dialogue_manager.show_dialogue(
		"Мама",
		"Михаил, просыпайся. Завтрак уже готов."
	)


func start_svetik_scene() -> void:
	scene_stage = 3

	mama.hide()
	svetik.show()

	dialogue_manager.show_dialogue(
		"Светик",
		"Привет, Михаил. Наконец-то мы познакомились."
	)
