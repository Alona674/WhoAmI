extends InteractableBase


func _ready() -> void:
	interaction_name = "кувшин"


func interact() -> void:
	get_tree().current_scene.jug_interacted()
