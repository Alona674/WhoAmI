extends InteractableBase


func _ready() -> void:
	interaction_name = "Сковорода"


func interact() -> void:
	get_tree().current_scene.pan_interacted()
