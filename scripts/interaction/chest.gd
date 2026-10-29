extends InteractableBase


func _ready() -> void:
	interaction_name = "хлебницу"


func interact() -> void:
	get_tree().current_scene.chest_interacted()
