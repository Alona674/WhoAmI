extends CanvasLayer

signal dialogue_closed

@onready var dialogue_box: Control = $DialogueBox
@onready var text_label: Label = $DialogueBox/Text
@onready var speaker_label: Label = $DialogueBox/Speaker


var is_open: bool = false
var typing: bool = false
var full_text: String = ""
var typing_speed: float = 0.03


func _ready() -> void:
	dialogue_box.hide()


func show_dialogue(speaker: String, text: String) -> void:
	is_open = true
	typing = true
	full_text = text

	speaker_label.text = speaker
	text_label.text = ""

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
		text_label.text += character
		await get_tree().create_timer(typing_speed).timeout

	typing = false


func hide_dialogue() -> void:
	is_open = false
	dialogue_box.hide()
	dialogue_closed.emit()

	var fade_tween := create_tween()
	fade_tween.tween_property(
		dialogue_box,
		"modulate:a",
		0.0,
		0.2
	)

	await fade_tween.finished

	dialogue_box.hide()


func _input(event: InputEvent) -> void:
	if not is_open:
		return

	if event.is_action_pressed("interact"):
		if typing:
			text_label.text = full_text
			typing = false
			get_viewport().set_input_as_handled()
			return

		hide_dialogue()
		get_viewport().set_input_as_handled()
