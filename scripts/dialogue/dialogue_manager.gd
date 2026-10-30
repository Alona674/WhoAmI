extends CanvasLayer

signal dialogue_closed

@onready var continue_hint: Label = $DialogueBox/ContinueHint
@onready var dialogue_box: Control = $DialogueBox
@onready var text_label: Label = $DialogueBox/Text
@onready var speaker_label: Label = $DialogueBox/Speaker
@onready var end_button: Button = $DialogueBox/EndButton
@onready var write_button: Button = $DialogueBox/WriteButton
@onready var message_input: LineEdit = $DialogueBox/MessageInput
@onready var send_button: Button = $DialogueBox/SendButton

var player: CharacterBody2D
var is_open: bool = false
var typing: bool = false
var closing: bool = false
var waiting_for_chat: bool = false
var chat_enabled: bool = false
var temporarily_summoned_svetik: bool = false
var typing_speed: float = 0.03
var typing_tween: Tween


func _ready() -> void:
	dialogue_box.hide()
	continue_hint.hide()
	end_button.pressed.connect(hide_dialogue)
	write_button.pressed.connect(_on_write_pressed)
	send_button.pressed.connect(_send_message)
	message_input.text_submitted.connect(_on_message_submitted)
	SvetikClient.chat_reply.connect(_on_chat_reply)


func show_dialogue(speaker: String, text: String, allow_chat: bool = false) -> void:
	if is_open or closing:
		return
	player = get_tree().get_first_node_in_group("player")
	if player != null:
		player.can_move = false
	is_open = true
	chat_enabled = allow_chat
	waiting_for_chat = false
	speaker_label.text = speaker
	_set_dialogue_text(text)
	end_button.hide()
	write_button.hide()
	message_input.hide()
	send_button.hide()
	continue_hint.hide()
	dialogue_box.modulate.a = 1.0
	dialogue_box.show()


func _set_dialogue_text(text: String) -> void:
	text_label.text = text
	text_label.visible_characters = 0
	typing = true
	continue_hint.hide()
	if typing_tween:
		typing_tween.kill()
	typing_tween = create_tween()
	typing_tween.tween_property(text_label, "visible_characters", text.length(), text.length() * typing_speed)
	typing_tween.tween_callback(_on_typing_finished)


func _on_typing_finished() -> void:
	if not is_open:
		return
	typing = false
	if chat_enabled:
		end_button.show()
		write_button.show()
	else:
		continue_hint.show()


func hide_dialogue() -> void:
	if closing or not is_open:
		return
	closing = true
	is_open = false
	waiting_for_chat = false
	typing = false
	if typing_tween:
		typing_tween.kill()
	continue_hint.hide()
	end_button.hide()
	write_button.hide()
	message_input.hide()
	send_button.hide()
	await create_tween().tween_property(dialogue_box, "modulate:a", 0.0, 0.2).finished
	dialogue_box.hide()
	closing = false
	if is_instance_valid(player):
		player.can_move = true
	if temporarily_summoned_svetik:
		var svetik = get_tree().current_scene.get_node_or_null("Svetik")
		if svetik != null:
			svetik.hide()
		temporarily_summoned_svetik = false
	dialogue_closed.emit()


func _open_chat() -> void:
	if is_open or closing:
		return
	var svetik = get_tree().current_scene.get_node_or_null("Svetik")
	if svetik != null and not svetik.visible:
		temporarily_summoned_svetik = true
		svetik.show()
	show_dialogue("Светик", "Я слушаю, Миша.", true)


func _input(event: InputEvent) -> void:
	if get_tree().paused or event.is_echo():
		return
	# E advances/closes ordinary dialogue. Svetik's chat stays open until Tab,
	# so typing or trying to dismiss his reply never eats the player's message.
	if is_open and not chat_enabled and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if typing:
			if typing_tween:
				typing_tween.kill()
			text_label.visible_characters = -1
			_on_typing_finished()
		else:
			hide_dialogue()
		return
	if event.is_action_pressed("chat"):
		if is_open:
			if chat_enabled:
				get_viewport().set_input_as_handled()
				hide_dialogue()
		else:
			get_viewport().set_input_as_handled()
			_open_chat()


func _on_write_pressed() -> void:
	message_input.show()
	send_button.show()
	write_button.hide()
	message_input.grab_focus()


func _send_message() -> void:
	var message := message_input.text.strip_edges()
	if message.is_empty() or waiting_for_chat:
		return
	waiting_for_chat = true
	message_input.clear()
	message_input.hide()
	send_button.hide()
	write_button.hide()
	text_label.text = "Светик думает..."
	text_label.visible_characters = -1
	continue_hint.hide()
	SvetikClient.send_chat(message)


func _on_message_submitted(_text: String) -> void:
	_send_message()


func _on_chat_reply(text: String, actions: Array) -> void:
	if not is_open or not waiting_for_chat:
		return
	waiting_for_chat = false
	SvetikWorld.apply_actions(actions)
	speaker_label.text = "Светик"
	_set_dialogue_text(text)
