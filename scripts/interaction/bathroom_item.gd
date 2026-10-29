extends InteractableBase

@export_enum("sink", "mirror") var item_id: String = "sink"


func interact() -> void:
	get_parent().interact_item(item_id)
