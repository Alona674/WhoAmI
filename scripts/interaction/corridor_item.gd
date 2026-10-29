extends InteractableBase

@export_enum("globe", "flowers", "picture", "chair") var item_id: String = "globe"

func interact() -> void:
	get_parent().interact_item(item_id)
