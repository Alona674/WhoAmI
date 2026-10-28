extends CanvasLayer

signal dialogue_closed
@onready var continue_hint: Label = $DialogueBox/ContinueHint
@onready var dialogue_box: Control = $DialogueBox
@onready var text_label: Label = $DialogueBox/Text
@onready var speaker_label: Label = $DialogueBox/Speaker
var player: CharacterBody2D


var is_open: bool = false
var typing: bool = false
var full_text: String = ""
var typing_speed: float = 0.03


func _ready() -> void:
	dialogue_box.hide()
	continue_hint.hide()


func show_dialogue(speaker: String, text: String) -> void:
	player = get_tree().get_first_node_in_group("player")
	if player != null:
		player.can_move = false
	is_open = true
	typing = true
	full_text = text

	speaker_label.text = speaker
	text_label.text = ""

	continue_hint.hide()

	dialogue_box.modulate.a = 0.0
	dialogue_box.show()

	var fade_tween := create_tween()
	fade_tween.tween_property(
		dialogue_box,
		"modulate:a",
		1.0,
		0.35
	)

	for character in full_text:
		if not typing:
			break

		text_label.text += character
		await get_tree().create_timer(typing_speed).timeout

	typing = false
	continue_hint.show()


func hide_dialogue() -> void:
	if player != null:
		player.can_move = true
	is_open = false
	typing = false
	continue_hint.hide()

	var fade_tween := create_tween()
	fade_tween.tween_property(
		dialogue_box,
		"modulate:a",
		0.0,
		0.2
	)

	await fade_tween.finished

	dialogue_box.hide()
	dialogue_closed.emit()



func _input(event: InputEvent) -> void:
	if not is_open:
		return

	if event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()

		if typing:
			text_label.text = full_text
			typing = false
			return

		hide_dialogue()
