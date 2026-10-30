extends InteractableBase


func _ready() -> void:
	interaction_name = "Кувшин"


func interact() -> void:
	get_tree().current_scene.jug_interacted()
