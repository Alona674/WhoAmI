extends CanvasLayer
signal dialogue_closed
@onready var continue_hint: Label = $DialogueBox/ContinueHint
@onready var dialogue_box: Control = $DialogueBox
@onready var text_label: Label = $DialogueBox/Text
@onready var speaker_label: Label = $DialogueBox/Speaker
var player: CharacterBody2D
var is_open: bool = false
var typing: bool = false
var closing: bool = false
var full_text: String = ""
var typing_speed: float = 0.03
var typing_tween: Tween

func _ready() -> void:
	dialogue_box.hide()
	continue_hint.hide()

func show_dialogue(speaker: String, text: String) -> void:
	if is_open or closing:
		return
	player = get_tree().get_first_node_in_group("player")
	if player != null:
		player.can_move = false
	is_open = true
	typing = true
	full_text = text
	speaker_label.text = speaker
	text_label.text = text
	text_label.visible_characters = 0
	continue_hint.hide()
	dialogue_box.modulate.a = 1.0
	dialogue_box.show()
	typing_tween = create_tween()
	typing_tween.tween_property(text_label,"visible_characters",text.length(),text.length()*typing_speed)
	typing_tween.tween_callback(func(): typing = false; continue_hint.show())

func hide_dialogue() -> void:
	if closing or not is_open:
		return
	closing = true
	is_open = false
	typing = false
	if typing_tween:
		typing_tween.kill()
	continue_hint.hide()
	await create_tween().tween_property(dialogue_box,"modulate:a",0.0,0.2).finished
	dialogue_box.hide()
	closing = false
	if is_instance_valid(player):
		player.can_move = true
	dialogue_closed.emit()

func _input(event: InputEvent) -> void:
	if (is_open or closing) and event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if closing:
			return
		if typing:
			typing_tween.kill()
			text_label.visible_characters = -1
			typing = false
			continue_hint.show()
		else:
			hide_dialogue()
