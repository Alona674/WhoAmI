extends InteractableBase


func _ready() -> void:
	interaction_name = "весы"


func interact() -> void:
	get_tree().current_scene.scales_interacted()
