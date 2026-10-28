
extends Area2D

@onready var bedroom = get_parent()
@onready var wardrobe_open: Sprite2D = bedroom.get_node("WardrobeOpen")
@onready var loot_panel = bedroom.get_node("UILayer/WardrobeLootPanel")

var is_open: bool = false

var wardrobe_items: Array[Dictionary] = [
	{
		"id": "chess_king",
		"name": "Шахматный король",
		"texture": preload("res://art/items/bedroom/шахматный король из шкафа.png")
	},
	{
		"id": "super_weapon",
		"name": "Супероружие",
		"texture": preload("res://art/items/bedroom/вилка из шкафа.png")
	},
	{
		"id": "evil_blaster",
		"name": "Супер-пупер бластер",
		"texture": preload("res://art/items/bedroom/Палка из шкафа.png")
	},
	{
		"id": "lighter",
		"name": "Зажигалка",
		"texture": preload("res://art/items/bedroom/Зажигалка из шкафа.png")
	}
]


func _ready() -> void:
	wardrobe_open.hide()
	loot_panel.item_taken.connect(_on_item_taken)


func interact() -> void:
	wardrobe_open.show()
	loot_panel.open_container(wardrobe_items)
	is_open = true


func _on_item_taken(item_id: String) -> void:
	for i in range(wardrobe_items.size()):
		if wardrobe_items[i].get("id", "") == item_id:
			wardrobe_items.remove_at(i)
			break
