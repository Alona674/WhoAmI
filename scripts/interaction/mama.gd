extends InteractableBase


@onready var dialogue_manager = get_node("../DialogueManager")


func _ready() -> void:
	interaction_name = "Мама"


func interact() -> void:
	dialogue_manager.show_dialogue(
		"Мама",
		"Доброе утро, Михаил. Иди завтракать."
	)
