extends InteractableBase

@export var cabinet_title: String = "Тумбочка"
@export var contents: Array[Dictionary] = []
@export var background_path: NodePath = NodePath("../Background")
@export var door_rect: Rect2 = Rect2(736, 489, 102, 70)
var panel: Control
var interior: Polygon2D
var doors: Array[Sprite2D] = []
var is_open: bool = false

func _ready() -> void:
	panel = get_parent().get_node("UILayer/ContainerPanel")
	panel.closed.connect(_close)
	var background: Sprite2D = get_node(background_path)
	interior = Polygon2D.new()
	interior.color = Color(0.12, 0.07, 0.03)
	var r := door_rect
	interior.polygon = PackedVector2Array([r.position, r.position+Vector2(r.size.x,0),r.end,r.position+Vector2(0,r.size.y)])
	get_parent().add_child.call_deferred(interior)
	interior.hide()
	for side in range(2):
		var door := Sprite2D.new()
		door.texture = background.texture
		door.region_enabled = true
		door.region_rect = Rect2(r.position+Vector2(side*r.size.x/2,0),Vector2(r.size.x/2,r.size.y))
		door.centered = false
		door.position = r.position+Vector2(side*r.size.x,0)
		if side == 1:
			door.offset.x = -r.size.x/2
		get_parent().add_child.call_deferred(door)
		door.hide()
		doors.append(door)

func interact() -> void:
	if is_open:
		return
	is_open = true
	interior.show()
	for door in doors:
		door.show()
		door.scale.x = 1.0
		create_tween().tween_property(door,"scale:x",0.25,0.25)
	var remaining: Array = []
	for item in contents:
		if not GameState.get_flag("collected_"+str(item.id)):
			remaining.append(item)
	panel.open_container(cabinet_title,remaining)

func _close() -> void:
	if not is_open:
		return
	is_open = false
	interior.hide()
	for door in doors:
		door.hide()
