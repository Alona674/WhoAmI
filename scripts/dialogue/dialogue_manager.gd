extends CanvasLayer

signal dialogue_closed

@onready var dialogue_box: Control = $DialogueBox
@onready var text_label: Label = $DialogueBox/Text
@onready var speaker_label: Label = $DialogueBox/Speaker


var is_open: bool = false


func _ready() -> void:
	dialogue_box.hide()


func show_dialogue(speaker: String, text: String) -> void:
	is_open = true

	speaker_label.text = speaker
	text_label.text = text

	dialogue_box.show()


func hide_dialogue() -> void:
	is_open = false
	dialogue_box.hide()
	dialogue_closed.emit()


func _input(event: InputEvent) -> void:
	if not is_open:
		return

	if event.is_action_pressed("interact"):
		hide_dialogue()
		get_viewport().set_input_as_handled()
