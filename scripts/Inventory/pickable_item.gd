extends Area2D

@export var item_id: String = "old_compass"
@export var item_name: String = "Старый компас"
@export var item_description: String = "Стрелка бешено крутится во все стороны. Кажется, он указывает на что-то магическое."
@export var icon_path: String = ""

func _ready() -> void:
	if GameState.get_flag("collected_" + item_id) or InventoryManager.has_item(item_id):
		queue_free()
		return
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player" and not body.is_in_group("player"):
		return
	InventoryManager.add_item(item_id, item_name, item_description, icon_path)
	GameState.set_flag("collected_" + item_id)
	queue_free()
