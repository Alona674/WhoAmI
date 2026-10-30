extends CanvasLayer

const PICKABLE_ITEM_SCENE: PackedScene = preload("res://scenes/Item/PickableItem.tscn")

@onready var items_list: ItemList = $PanelContainer/MainLayout/ItemsList
@onready var description_label: Label = $PanelContainer/MainLayout/DescriptionLabel
@onready var drop_button: Button = $PanelContainer/MainLayout/DropButton

# Переменная, чтобы помнить, какой предмет сейчас выбран
var selected_index: int = -1

func _ready() -> void:
	hide()
	InventoryManager.inventory_updated.connect(refresh_ui)
	items_list.item_selected.connect(_on_item_selected)
	drop_button.pressed.connect(_on_drop_button_pressed) # Подключаем кнопку выброса
	
	drop_button.disabled = true # Кнопка отключена, пока ничего не выбрано
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
	drop_button.disabled = true
	selected_index = -1
	
	# Принудительно задаем размер для ВСЕХ иконок в списке (например, 32 на 32 пикселя)
	items_list.fixed_icon_size = Vector2i(32, 32)
	
	for item in InventoryManager.items:
		var icon_texture: Texture2D = null
		
		if item.get("icon_path", "") != "":
			icon_texture = load(item["icon_path"])
		
		# Передаем и имя, и текстуру
		items_list.add_item(item["name"], icon_texture)



func _on_item_selected(index: int) -> void:
	selected_index = index
	var current_items = InventoryManager.items
	if index >= 0 and index < current_items.size():
		description_label.text = current_items[index]["description"]
		drop_button.disabled = false # Активируем кнопку выброса при выборе предмета


# Логика выбрасывания предмета под ноги Михаилу
func _on_drop_button_pressed() -> void:
	if selected_index < 0:
		return
	var current_room := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if current_room == null or player == null:
		return
	var item_to_drop: Dictionary = InventoryManager.remove_item_at(selected_index)
	if item_to_drop.is_empty():
		return

	var drop_node := PICKABLE_ITEM_SCENE.instantiate() as Area2D
	drop_node.set("item_id", item_to_drop.get("id", ""))
	drop_node.set("item_name", item_to_drop.get("name", "Предмет"))
	drop_node.set("item_description", item_to_drop.get("description", ""))
	drop_node.set("icon_path", item_to_drop.get("icon_path", ""))
	var sprite := drop_node.get_node("Sprite2D") as Sprite2D
	var icon_path: String = str(item_to_drop.get("icon_path", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		sprite.texture = load(icon_path)
	sprite.scale = Vector2(0.08, 0.08)

	var drop_direction := 1.0
	if player.global_position.x + 90.0 > float(player.get("right_limit")):
		drop_direction = -1.0
	var drop_x := clampf(
		player.global_position.x + 90.0 * drop_direction,
		float(player.get("left_limit")) + 30.0,
		float(player.get("right_limit")) - 30.0
	)
	current_room.add_child(drop_node)
	drop_node.global_position = Vector2(drop_x, player.global_position.y - 10.0)
	refresh_ui()
