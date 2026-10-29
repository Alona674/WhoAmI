extends InteractableBase


func _ready() -> void:
	interaction_name = "сковороду"


func interact() -> void:
	get_tree().current_scene.pan_interacted()
