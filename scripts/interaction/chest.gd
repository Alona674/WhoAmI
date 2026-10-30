extends InteractableBase


func _ready() -> void:
	interaction_name = "Хлебница"
	interaction_action = "Открыть"


func interact() -> void:
	get_tree().current_scene.chest_interacted()
