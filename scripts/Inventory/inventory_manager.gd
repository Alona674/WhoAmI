extends Node

signal inventory_updated

# Добавили пустую строку "icon_path": "" по умолчанию ко всем известным предметам
const KNOWN_ITEMS := {
	"teddy": {"name": "Тедди", "description": "Друг Михаила с самого детства.", "icon_path": "res://art/items/bedroom/Teddy.png"},
	"chess_king": {"name": "Шахматный король", "description": "Шахматная фигура из шкафа.", "icon_path": "res://art/items/bedroom/шахматный король из шкафа.png"},
	"super_weapon": {"name": "Супероружие", "description": "Сокровище из шкафа.", "icon_path": "res://art/items/bedroom/вилка из шкафа.png"},
	"evil_blaster": {"name": "Супер-пупер бластер", "description": "Сокровище из шкафа.", "icon_path": "res://art/items/bedroom/Палка из шкафа.png"},
	"lighter": {"name": "Зажигалка", "description": "Зажигалка из шкафа.", "icon_path": "res://art/items/bedroom/Зажигалка из шкафа.png"},
	"dirty_sock": {"name": "Грязный носок", "description": "Носок из корзины с бельём.", "icon_path": "res://art/items/bathroom/dirty_sock.png"}
}

var items: Array[Dictionary]:
	get:
		var result: Array[Dictionary] = []
		for item_id in GameState.inventory:
			var details: Dictionary = GameState.inventory_details.get(item_id, KNOWN_ITEMS.get(item_id, {}))
			var known: Dictionary = KNOWN_ITEMS.get(item_id, {})
			var icon_path: String = str(details.get("icon_path", ""))
			if icon_path.is_empty():
				icon_path = str(known.get("icon_path", ""))
			result.append({
				"id": item_id, 
				"name": details.get("name", item_id), 
				"description": details.get("description", ""),
				"icon_path": icon_path
			})
		return result


func _ready() -> void:
	GameState.inventory_updated.connect(func(): inventory_updated.emit())


# Добавили параметр icon_path
func add_item(item_id: String, item_name: String, description: String, icon_path: String = "") -> void:
	GameState.inventory_details[item_id] = {"name": item_name, "description": description, "icon_path": icon_path}
	if GameState.has_item(item_id):
		inventory_updated.emit()
	else:
		GameState.add_item(item_id)


func remove_item(item_id: String) -> bool:
	if not GameState.has_item(item_id):
		return false
	GameState.remove_item(item_id)
	return true


# НОВАЯ ФУНКЦИЯ: Удаляет предмет по индексу из списка UI и возвращает его данные для спавна на пол
func remove_item_at(index: int) -> Dictionary:
	var current_items = items
	if index >= 0 and index < current_items.size():
		var removed_item = current_items[index]
		var item_id: String = removed_item["id"]
		GameState.remove_item(item_id)
		GameState.inventory_details.erase(item_id)
		GameState.set_flag("collected_" + item_id, false)
		return removed_item
	return {}


func has_item(item_id: String) -> bool:
	return GameState.has_item(item_id)
