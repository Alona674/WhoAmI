
extends Control

signal diary_closed

@onready var background: ColorRect = $Background
@onready var spread: TextureRect = $Background/Spread
@onready var torn_pages: TextureRect = $Background/TornPages
@onready var history_button: Button = $Background/Tabs/HistoryButton
@onready var quests_button: Button = $Background/Tabs/QuestsButton

const DIARY_MICHAEL: Texture2D = preload("res://art/items/bedroom/diary_blank.png")
const DIARY_BLANK: Texture2D = preload("res://art/items/bedroom/diary_michael.png")

func has_svetik_appeared() -> bool:
	return GameState.svetik_has_appeared

var current_tab: String = "history"
var page_scene_playing: bool = false


func _ready() -> void:
	hide()

	history_button.pressed.connect(_on_history_pressed)
	quests_button.pressed.connect(_on_quests_pressed)

	torn_pages.hide()
	show_history()


func open_diary() -> void:
	if visible:
		return

	show()
	show_history()

	if GameState.svetik_has_appeared and not GameState.diary_svetik_intro_seen:
		await play_svetik_page_scene()


func close_diary() -> void:
	if page_scene_playing:
		return

	hide()
	diary_closed.emit()


func show_history() -> void:
	current_tab = "history"
	torn_pages.hide()

	if GameState.svetik_has_appeared:
		spread.texture = DIARY_BLANK
	else:
		spread.texture = DIARY_MICHAEL




func play_svetik_page_scene() -> void:
	page_scene_playing = true

	spread.texture = DIARY_BLANK

	torn_pages.set_anchors_preset(Control.PRESET_TOP_LEFT)
	torn_pages.position = spread.position
	torn_pages.size = spread.size
	torn_pages.texture = DIARY_MICHAEL
	torn_pages.rotation = 0.0
	torn_pages.scale = Vector2.ONE
	torn_pages.modulate.a = 1.0
	torn_pages.show()

	# Светик готовится вырвать страницы.
	await get_tree().create_timer(0.12).timeout

	# Резкий рывок!
	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		torn_pages,
		"position",
		torn_pages.position + Vector2(500, -1100),
		0.28
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	tween.tween_property(
		torn_pages,
		"rotation_degrees",
		35.0,
		0.28
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	tween.tween_property(
		torn_pages,
		"scale",
		Vector2(0.75, 0.75),
		0.28
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	tween.tween_property(
		torn_pages,
		"modulate:a",
		0.0,
		0.18
	).set_delay(0.08)

	await tween.finished

	torn_pages.hide()
	torn_pages.rotation = 0.0
	torn_pages.scale = Vector2.ONE
	torn_pages.modulate.a = 1.0

	GameState.diary_svetik_intro_seen = true
	page_scene_playing = false



func show_quests() -> void:
	current_tab = "quests"
	# Список заданий подключим следующим шагом.


func _on_history_pressed() -> void:
	show_history()


func _on_quests_pressed() -> void:
	show_quests()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_diary") and not event.is_echo():
		toggle_diary()
		get_viewport().set_input_as_handled()
		return

	if not visible:
		return

	if event.is_action_pressed("interact") and not event.is_echo():
		close_diary()
		get_viewport().set_input_as_handled()

func toggle_diary() -> void:
	if visible:
		close_diary()
	else:
		open_diary()
