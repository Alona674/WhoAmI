extends InteractableBase


func _ready() -> void:
	interaction_name = "Тедди"


func interact() -> void:
	var bedroom = get_parent()

	if bedroom.has_method("teddy_interacted"):
		bedroom.teddy_interacted()
