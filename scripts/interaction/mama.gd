
extends InteractableBase

@onready var dialogue_manager = get_node("../DialogueManager")

var can_interact: bool = false


func _ready() -> void:
	interaction_name = "Мама"
	can_interact = false


func interact() -> void:
	if not can_interact:
		return

	dialogue_manager.show_dialogue(
		"Мама",
		"Доброе утро, Михаил. Иди завтракать."
	)
