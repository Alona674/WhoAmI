extends Node

var flags: Dictionary = {}

var inventory: Array[String] = []


func set_flag(flag_name: String, value: bool = true) -> void:
	flags[flag_name] = value


func get_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)


func add_item(item_id: String) -> void:
	if not inventory.has(item_id):
		inventory.append(item_id)


func has_item(item_id: String) -> bool:
	return inventory.has(item_id)


func remove_item(item_id: String) -> void:
	inventory.erase(item_id)
