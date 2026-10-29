extends InteractableBase

@onready var wardrobe_open: Sprite2D = $OpenSprite
@onready var loot_panel = get_parent().get_node("UILayer/ContainerPanel")
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
	loot_panel.closed.connect(_close)

func interact() -> void:
	if is_open:
		return
	is_open = true
	wardrobe_open.show()
	loot_panel.open_container("Содержимое шкафа", wardrobe_items)

func _close() -> void:
	is_open = false
	wardrobe_open.hide()
