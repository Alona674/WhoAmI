
extends Node

const SAVE_PATH: String = "user://savegame.json"

var flags: Dictionary = {}
var inventory: Array[String] = []

# Состояние вступления в спальне
var bedroom_intro_completed: bool = false

# Точка появления персонажа после перехода между комнатами
var next_spawn_point: String = ""

# Данные сохранения
var saved_scene: String = ""
var saved_player_position: Vector2 = Vector2.ZERO
var has_pending_player_position: bool = false


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


func save_game() -> bool:
	var player = get_tree().get_first_node_in_group("player")

	if player == null:
		push_warning("Не удалось сохранить игру: Player не найден.")
		return false

	var current_scene = get_tree().current_scene

	if current_scene == null:
		push_warning("Не удалось сохранить игру: текущая сцена не найдена.")
		return false

	var save_data: Dictionary = {
		"scene": current_scene.scene_file_path,
		"player_position_x": player.global_position.x,
		"player_position_y": player.global_position.y,
		"flags": flags,
		"inventory": inventory,
		"bedroom_intro_completed": bedroom_intro_completed
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		push_warning("Не удалось открыть файл сохранения.")
		return false

	file.store_string(JSON.stringify(save_data))
	file.close()

	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		push_warning("Файл сохранения не найден.")
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		push_warning("Не удалось открыть файл сохранения.")
		return false

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)

	if error != OK:
		push_warning("Не удалось прочитать файл сохранения.")
		return false

	var save_data = json.data

	if not save_data is Dictionary:
		push_warning("Файл сохранения имеет неверный формат.")
		return false

	var scene_path: String = save_data.get("scene", "")

	if scene_path == "" or not ResourceLoader.exists(scene_path):
		push_warning("Сохранённая сцена не найдена.")
		return false

	# Восстанавливаем сюжетные данные
	flags = save_data.get("flags", {})

	inventory.clear()
	for item in save_data.get("inventory", []):
		inventory.append(str(item))

	bedroom_intro_completed = save_data.get(
		"bedroom_intro_completed", false
	)

	# Запоминаем комнату и позицию игрока
	saved_scene = scene_path
	saved_player_position = Vector2(
		float(save_data.get("player_position_x", 0.0)),
		float(save_data.get("player_position_y", 0.0))
	)
	has_pending_player_position = true

	# При загрузке сохранения обычный переход не нужен
	next_spawn_point = ""

	var error_code = get_tree().change_scene_to_file(scene_path)

	if error_code != OK:
		has_pending_player_position = false
		push_warning("Не удалось открыть сохранённую сцену.")
		return false

	return true
