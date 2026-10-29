extends InteractableBase

@export_enum("sink", "mirror", "basket") var item_id: String = "sink"


func interact() -> void:
	get_parent().interact_item(item_id)
