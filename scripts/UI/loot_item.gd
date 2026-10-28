
extends Panel

signal item_double_clicked(item_id: String)

@onready var icon_rect: TextureRect = $Icon
@onready var name_label: Label = $ItemName

var item_id: String = ""
var item_name: String = ""
var item_texture: Texture2D

var click_count: int = 0
var last_click_time: float = 0.0


func setup(id: String, display_name: String, texture: Texture2D) -> void:
	item_id = id
	item_name = display_name
	item_texture = texture

	if is_node_ready():
		update_display()


func _ready() -> void:
	update_display()


func update_display() -> void:
	icon_rect.texture = item_texture
	name_label.text = item_name


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if event.double_click:
				item_double_clicked.emit(item_id)
				accept_event()
