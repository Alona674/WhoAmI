
extends Control

signal diary_closed

@onready var background: ColorRect = $Background
@onready var spread: TextureRect = $Background/Spread
@onready var history_button: Button = $Background/Tabs/HistoryButton
@onready var quests_button: Button = $Background/Tabs/QuestsButton

const DIARY_MICHAEL: Texture2D = preload("res://art/items/bedroom/diary_michael.png")
const DIARY_BLANK: Texture2D = preload("res://art/items/bedroom/diary_blank.png")

func has_svetik_appeared() -> bool:
	return GameState.svetik_has_appeared
	
var current_tab: String = "history"

func _ready() -> void:
	hide()

	history_button.pressed.connect(_on_history_pressed)
	quests_button.pressed.connect(_on_quests_pressed)

	show_history()

func open_diary() -> void:
	show()
	show_history()

func close_diary() -> void:
	hide()
	diary_closed.emit()

func show_history() -> void:
	current_tab = "history"

	if has_svetik_appeared():
		spread.texture = DIARY_BLANK
	else:
		spread.texture = DIARY_MICHAEL

func show_quests() -> void:
	current_tab = "quests"
	# Список заданий подключим следующим шагом.

func _on_history_pressed() -> void:
	show_history()

func _on_quests_pressed() -> void:
	show_quests()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close_diary()
		get_viewport().set_input_as_handled()
