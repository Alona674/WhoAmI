extends Node

signal inventory_updated

const KNOWN_ITEMS := {
	"teddy": {"name": "Тедди", "description": "Друг Михаила с самого детства."},
	"chess_king": {"name": "Шахматный король", "description": "Шахматная фигура из шкафа."},
	"super_weapon": {"name": "Супероружие", "description": "Сокровище из шкафа."},
	"evil_blaster": {"name": "Супер-пупер бластер", "description": "Сокровище из шкафа."},
	"lighter": {"name": "Зажигалка", "description": "Зажигалка из шкафа."},
	"dirty_sock": {"name": "Грязный носок", "description": "Носок из корзины с бельём."}
}

var items: Array[Dictionary]:
	get:
		var result: Array[Dictionary] = []
		for item_id in GameState.inventory:
			var details: Dictionary = GameState.inventory_details.get(item_id, KNOWN_ITEMS.get(item_id, {}))
			result.append({"id": item_id, "name": details.get("name", item_id), "description": details.get("description", "")})
		return result


func _ready() -> void:
	GameState.inventory_updated.connect(func(): inventory_updated.emit())


func add_item(item_id: String, item_name: String, description: String) -> void:
	GameState.inventory_details[item_id] = {"name": item_name, "description": description}
	if GameState.has_item(item_id):
		inventory_updated.emit()
	else:
		GameState.add_item(item_id)


func remove_item(item_id: String) -> bool:
	if not GameState.has_item(item_id):
		return false
	GameState.remove_item(item_id)
	return true


func has_item(item_id: String) -> bool:
	return GameState.has_item(item_id)
