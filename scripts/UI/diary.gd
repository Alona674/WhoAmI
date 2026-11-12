
extends Control

signal diary_closed

@onready var spread: TextureRect = $Background/Spread
@onready var torn_pages: TextureRect = $Background/TornPages
@onready var left_page: Control = $Background/LeftPage
@onready var right_page: Control = $Background/RightPage
@onready var history_text: RichTextLabel = $Background/LeftPage/HistoryText
@onready var quest_text: RichTextLabel = $Background/RightPage/QuestText
@onready var page_turn: TextureRect = $Background/LeftPage/PageTurn
@onready var page_turn_back: TextureRect = $Background/RightPage/PageTurnBack
@onready var navigation: Control = $Background/Navigation
@onready var history_previous: Button = $Background/Navigation/History/Previous
@onready var history_next: Button = $Background/Navigation/History/Next
@onready var history_counter: Label = $Background/Navigation/History/Counter
@onready var quests_toggle: Button = $Background/Navigation/QuestsToggle

const DIARY_MICHAEL: Texture2D = preload("res://art/items/bedroom/diary_blank.png")
const DIARY_BLANK: Texture2D = preload("res://art/items/bedroom/diary_michael.png")

var page_scene_playing: bool = false
var turning_page: bool = false
var locked_player: CharacterBody2D

# История Светика
var history_pages: Array[String]:
	get:
		return GameState.diary_history_pages
var history_page_index: int = 0

# Задания
var active_quests: Array[Dictionary]:
	get:
		return GameState.diary_active_quests
var completed_quests: Array[Dictionary]:
	get:
		return GameState.diary_completed_quests
var quest_page_index: int = 0


func _ready() -> void:
	hide()
	
	page_turn.hide()
	page_turn_back.hide()

	page_turn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_turn_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	torn_pages.hide()
	


	history_text.bbcode_enabled = true
	quest_text.bbcode_enabled = true
	history_previous.pressed.connect(func(): animate_page_turn(false, -1))
	history_next.pressed.connect(func(): animate_page_turn(false, 1))
	quests_toggle.pressed.connect(func(): animate_page_turn(true))

	if GameState.diary_svetik_intro_seen:
		spread.texture = DIARY_BLANK
	else:
		spread.texture = DIARY_MICHAEL

	history_text.text = ""
	quest_text.text = ""

	_update_pages()


func open_diary() -> void:
	if visible or _is_editing_text() or _has_other_modal() or get_tree().paused:
		return

	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player != null:
		if not player.can_move:
			return
		locked_player = player
		locked_player.can_move = false
		locked_player.velocity = Vector2.ZERO
		if is_instance_valid(locked_player.interaction_prompt):
			locked_player.interaction_prompt.hide()

	show()
	_update_pages()

	if GameState.svetik_has_appeared and not GameState.diary_svetik_intro_seen:
		await play_svetik_page_scene()


func _is_editing_text() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit


func _is_dialogue_active() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	var dialogue := scene.get_node_or_null("DialogueManager")
	return dialogue != null and (dialogue.is_open or dialogue.closing)


func _has_other_modal() -> bool:
	if _is_dialogue_active():
		return true
	var scene := get_tree().current_scene
	if scene == null:
		return false
	if scene.get("busy") == true:
		return true
	for path in ["UILayer/WindowView", "UILayer/ContainerPanel", "UILayer/PauseMenu"]:
		var panel := scene.get_node_or_null(path) as Control
		if panel != null and panel.visible:
			return true
	return false


func _release_player() -> void:
	if is_instance_valid(locked_player) and not _has_other_modal():
		locked_player.can_move = true
	locked_player = null


func _exit_tree() -> void:
	_release_player()


func close_diary() -> void:
	if page_scene_playing or turning_page:
		return

	hide()
	_release_player()
	diary_closed.emit()


func toggle_diary() -> void:
	if visible:
		close_diary()
	else:
		open_diary()


# Добавить запись в историю Светика
func add_history_entry(entry: String) -> void:
	if history_pages.size() == 1 and history_pages[0].is_empty():
		history_pages[0] = entry
	else:
		history_pages.append(entry)
	history_page_index = history_pages.size() - 1
	_update_pages()


# Добавить новое задание
func add_quest(title: String, description: String) -> void:
	active_quests.append({
		"title": title,
		"description": description
	})

	quest_page_index = 0
	_update_pages()


# Завершить задание и переместить его в архив
func complete_quest(title: String) -> void:
	for i in range(active_quests.size()):
		if active_quests[i]["title"] == title:
			completed_quests.append(active_quests[i])
			active_quests.remove_at(i)
			quest_page_index = 0
			_update_pages()
			return


func _update_pages() -> void:
	if history_pages.is_empty():
		history_pages.append("")
	_update_navigation()

	history_text.text = ""
	quest_text.text = ""

	# Пока Светик не закончил переделывать дневник,
	# никаких игровых надписей на страницах нет.
	if not GameState.diary_svetik_intro_seen:
		return

	history_text.text = history_pages[history_page_index]
	if quest_page_index == 0:
		quest_text.text = "[center][b]АКТИВНЫЕ ЗАДАНИЯ[/b][/center]\n\n"

		for quest in active_quests:
			quest_text.text += "[b]" + quest["title"] + "[/b]\n"
			quest_text.text += quest["description"] + "\n\n"
	else:
		quest_text.text = "[center][b]ВЫПОЛНЕННЫЕ ЗАДАНИЯ[/b][/center]\n\n"

		for quest in completed_quests:
			quest_text.text += "[b]" + quest["title"] + "[/b]\n"
			quest_text.text += quest["description"] + "\n\n"


func _update_navigation() -> void:
	navigation.visible = GameState.diary_svetik_intro_seen
	history_previous.disabled = turning_page or history_page_index <= 0
	history_next.disabled = turning_page or history_page_index >= history_pages.size() - 1
	history_counter.text = "%d / %d" % [history_page_index + 1, history_pages.size()]
	quests_toggle.disabled = turning_page
	quests_toggle.text = "Выполненные задания →" if quest_page_index == 0 else "← Активные задания"

func turn_history(direction: int) -> void:
	var new_index: int = history_page_index + direction

	if new_index < 0 or new_index >= history_pages.size():
		return

	history_page_index = new_index
	_update_pages()


func turn_quests() -> void:
	quest_page_index = 1 - quest_page_index
	_update_pages()


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

	await get_tree().create_timer(0.12).timeout

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
	_update_pages()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_diary") and not event.is_echo():
		if _is_editing_text() or (not visible and _is_dialogue_active()):
			return
		toggle_diary()
		get_viewport().set_input_as_handled()
		return

	if not visible:
		return

	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		close_diary()
		# Also consume Esc during an animation, while closing is blocked.
		get_viewport().set_input_as_handled()
		return

	# Keep gameplay windows from taking control while the diary owns movement.
	if event.is_action("chat") or event.is_action("inventory") or event.is_action("interact"):
		get_viewport().set_input_as_handled()

	if page_scene_playing or turning_page:
		return

	if event.is_action_pressed("interact") and not event.is_echo():
		close_diary()
		get_viewport().set_input_as_handled()
		return

	# Перелистывание клавиатурой
	if event is InputEventKey and event.pressed and not event.echo:
		if not GameState.diary_svetik_intro_seen:
			return

		if event.keycode == KEY_LEFT:
			animate_page_turn(false, -1)
			get_viewport().set_input_as_handled()

		elif event.keycode == KEY_RIGHT:
			animate_page_turn(false, 1)
			get_viewport().set_input_as_handled()

	# Перелистывание мышью
	if event is InputEventMouseButton:
		if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
			return

		if not GameState.diary_svetik_intro_seen:
			return

		# Leave scrollbars and navigation buttons to the GUI.
		for label in [history_text, quest_text]:
			var scrollbar = label.get_v_scroll_bar()
			if scrollbar.is_visible_in_tree() and scrollbar.get_global_rect().has_point(event.position):
				return
		var history_rect := left_page.get_global_rect()
		if history_rect.has_point(event.position):
			animate_page_turn(false, -1 if event.position.x < history_rect.get_center().x else 1)
		elif right_page.get_global_rect().has_point(event.position):
			animate_page_turn(true)
		else:
			return

		get_viewport().set_input_as_handled()
			

func animate_page_turn(is_right: bool, history_direction: int = -1) -> void:
	if turning_page or not GameState.diary_svetik_intro_seen:
		return
	if not is_right:
		var next_index := history_page_index + history_direction
		if next_index < 0 or next_index >= history_pages.size():
			return

	turning_page = true
	_update_navigation()

	# Transform the page and its text together around the book spine.
	var page: Control = right_page if is_right else left_page
	var overlay: TextureRect = page_turn_back if is_right else page_turn
	page.pivot_offset = Vector2(0 if is_right else page.size.x, page.size.y / 2.0)
	page.scale.x = 1.0
	overlay.show()

	# Страница складывается.
	var tween := create_tween()
	tween.tween_property(
		page,
		"scale:x",
		0.05,
		0.22
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await tween.finished

	# Обновляем содержимое дневника.
	if is_right:
		turn_quests()
	else:
		turn_history(history_direction)

	# Страница раскрывается обратно.
	var tween_back := create_tween()
	tween_back.tween_property(
		page,
		"scale:x",
		1.0,
		0.22
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await tween_back.finished

	overlay.hide()
	turning_page = false
	_update_navigation()
