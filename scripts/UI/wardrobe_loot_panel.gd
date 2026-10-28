
extends Control

signal item_taken(item_id: String)
signal panel_closed

const MAX_ITEMS := 8

@onready var items_grid: GridContainer = $Background/ItemsGrid
@onready var take_all_button: Button = $Background/TakeAllButton
@onready var close_button: Button = $Background/CloseButton

var contents: Array[Dictionary] = []


func _ready() -> void:
	hide()

	take_all_button.pressed.connect(_on_take_all_pressed)
	close_button.pressed.connect(_on_close_pressed)


func open_container(items: Array[Dictionary]) -> void:
	clear_items()
	contents.clear()

	for item in items:
		if contents.size() >= MAX_ITEMS:
			break

		contents.append(item)

	for item in contents:
		var card_scene = load("res://loot_item.tscn")

		if card_scene == null:
			push_error("Не удалось загрузить res://loot_item.tscn")
			return

		var card = card_scene.instantiate()
		items_grid.add_child(card)

		card.setup(
			item.get("id", ""),
			item.get("name", "Предмет"),
			item.get("texture", null)
		)

		card.item_double_clicked.connect(_on_item_double_clicked)

	show()


func clear_items() -> void:
	for child in items_grid.get_children():
		child.queue_free()


func _on_item_double_clicked(item_id: String) -> void:
	for i in range(contents.size()):
		if contents[i].get("id", "") == item_id:
			contents.remove_at(i)
			item_taken.emit(item_id)
			break

	for card in items_grid.get_children():
		if card.item_id == item_id:
			card.queue_free()
			break


func _on_take_all_pressed() -> void:
	for item in contents:
		item_taken.emit(item.get("id", ""))

	contents.clear()
	clear_items()
	close_panel()


func _on_close_pressed() -> void:
	close_panel()


func close_panel() -> void:
	if not visible:
		return

	hide()
	panel_closed.emit()
