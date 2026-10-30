extends CanvasLayer

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
	if visible and not event.is_echo() and (event.is_action_pressed("inventory") or event.is_action_pressed("ui_inventory") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		toggle_inventory()


func _unhandled_input(event: InputEvent) -> void:
	if visible or get_tree().paused or event.is_echo():
		return
	if not (event.is_action_pressed("inventory") or event.is_action_pressed("ui_inventory")):
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
	if selected_index == -1:
		return
		
	# 1. Сначала полностью очищаем предмет из GameState, чтобы игра забыла про него
	var current_items = InventoryManager.items
	var item_to_remove = current_items[selected_index]
	var item_id = item_to_remove["id"]
	
	# Удаляем из списков GameState напрямую до того, как спавнить объект на пол
	if GameState.inventory.has(item_id):
		GameState.inventory.erase(item_id)
	if GameState.inventory_details.has(item_id):
		GameState.inventory_details.erase(item_id)
		
	# Сбрасываем сюжетный флаг сбора, чтобы шкаф/сундук считали его несобранным
	GameState.set_flag("collected_" + item_id, false)
	
	# Оповещаем менеджер инвентаря, что нужно принудительно обновить списки
	InventoryManager.inventory_updated.emit()
	
	# 2. Создаем физический объект на полу
	var drop_node = Area2D.new()
	drop_node.name = "Dropped_" + item_id
	
	# Добавляем визуальную картинку предмета
	var sprite = Sprite2D.new()
	if item_to_remove["icon_path"] != "":
		sprite.texture = load(item_to_remove["icon_path"])
		
		# ИСПРАВЛЕНИЕ РАЗМЕРА: Уменьшаем картинку еще сильнее (до 8% от оригинала)
		# Если будет слишком мелко, поменяйте 0.08 на 0.12
		sprite.scale = Vector2(0.08, 0.08) 
		
	drop_node.add_child(sprite)
	
	# Добавляем зону коллизии
	var collision = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 25.0 
	collision.shape = circle_shape
	drop_node.add_child(collision)
	
	# Прикрепляем к объекту логику подбора при столкновении
	var pickup_script = GDScript.new()
	pickup_script.source_code = """
extends Area2D

var item_id: String
var item_name: String
var item_description: String
var icon_path: String
var spawn_time: float = 0.0

func _ready():
	body_entered.connect(_on_body_entered)
	spawn_time = Time.get_ticks_msec() / 1000.0

func _on_body_entered(body):
	# Увеличиваем задержку до 1.5 секунд, чтобы избежать случайного моментального подбора
	if (Time.get_ticks_msec() / 1000.0) - spawn_time < 1.5:
		return
		
	if body.name.to_lower() == "player" or body.is_in_group("player"):
		InventoryManager.add_item(item_id, item_name, item_description, icon_path)
		queue_free()
"""
	pickup_script.reload()
	drop_node.set_script(pickup_script)
	
	# Заполняем созданный объект данными
	drop_node.item_id = item_id
	drop_node.item_name = item_to_remove["name"]
	drop_node.item_description = item_to_remove["description"]
	drop_node.icon_path = item_to_remove["icon_path"]
	
	# 3. Ищем правильное местоположение в комнате
	var current_room = get_tree().current_scene
	var player = current_room.find_child("Player", true, false)
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		
	if player:
		# Спавним рядом с игроком
		drop_node.global_position = player.global_position
		# Откидываем вправо чуть дальше (на 90 пикселей)
		drop_node.global_position.x += 90.0
		# ИСПРАВЛЕНИЕ ВЫСОТЫ: Поднимаем предмет повыше (минус по Y в Godot — это вверх)
		drop_node.global_position.y -= 10.0
		
	# Добавляем готовый предмет на карту текущей комнаты
	current_room.add_child(drop_node)
	
	# Полностью перерисовываем интерфейс инвентаря
	refresh_ui()
