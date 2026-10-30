extends CanvasLayer

@onready var items_list: ItemList = $PanelContainer/MainLayout/ItemsList
@onready var description_label: Label = $PanelContainer/MainLayout/DescriptionLabel


func _ready() -> void:
	hide()
	InventoryManager.inventory_updated.connect(refresh_ui)
	items_list.item_selected.connect(_on_item_selected)
	refresh_ui()


func _input(event: InputEvent) -> void:
	if visible and not event.is_echo() and (event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		toggle_inventory()


func _unhandled_input(event: InputEvent) -> void:
	if visible or get_tree().paused or event.is_echo():
		return
	if not event.is_action_pressed("inventory"):
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not player.can_move:
		return
	get_viewport().set_input_as_handled()
	toggle_inventory()


func toggle_inventory() -> void:
	if visible:
		hide()
		get_tree().paused = false
	else:
		refresh_ui()
		var player = get_tree().get_first_node_in_group("player")
		if player != null and is_instance_valid(player.interaction_prompt):
			player.interaction_prompt.hide()
		show()
		get_tree().paused = true


func refresh_ui() -> void:
	items_list.clear()
	description_label.text = "Выберите предмет, чтобы прочитать описание."
	for item in InventoryManager.items:
		items_list.add_item(item["name"])


func _on_item_selected(index: int) -> void:
	var current_items = InventoryManager.items
	if index >= 0 and index < current_items.size():
		description_label.text = current_items[index]["description"]
