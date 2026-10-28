extends InteractableBase


@onready var dialogue_manager = get_node("../DialogueManager")


func _ready() -> void:
	interaction_name = "Светик"


func interact() -> void:
	dialogue_manager.show_dialogue(
		"Светик",
		"Доброе утро, Михаил."
	)
