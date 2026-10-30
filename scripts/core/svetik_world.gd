extends Node

## Действия Светика в комнатах. Доступные объекты намеренно перечислены явно:
## двери, персонажи и сюжетные узлы командами модели не изменяются.
const ROOM_OBJECTS := {
	"Kitchen": ["Scales", "Chest", "Jug", "Pan"],
}
## Имена должны совпадать с корневыми узлами сцен (включая lowercase corridor).
const ROOM_NAMES := ["Bedroom", "corridor", "Kitchen", "Bathroom"]
const MOVED_OBJECT_SCRIPT := preload("res://scripts/core/svetik_moved_object.gd")
const OBJECT_VISUAL_DEFAULTS := {
	"Kitchen/Scales": {"texture_path": "res://art/items/scales.png", "sprite_scale_x": 0.075, "sprite_scale_y": 0.075, "shape_width": 120.0, "shape_height": 150.0, "shape_type": "RectangleShape2D"},
	"Kitchen/Chest": {"texture_path": "res://art/items/chest.png", "sprite_scale_x": 0.078, "sprite_scale_y": 0.078, "shape_width": 150.0, "shape_height": 100.0, "shape_type": "RectangleShape2D"},
	"Kitchen/Jug": {"texture_path": "res://art/items/jug_flowers.png", "sprite_scale_x": 0.09, "sprite_scale_y": 0.09, "shape_width": 100.0, "shape_height": 120.0, "shape_type": "RectangleShape2D"},
	"Kitchen/Pan": {"texture_path": "res://art/items/pan.png", "sprite_scale_x": 0.07, "sprite_scale_y": 0.07, "shape_width": 100.0, "shape_height": 100.0, "shape_type": "RectangleShape2D"},
}

var brightness: float = 1.0
var screen_rotation_degrees: float = 0.0


func _ready() -> void:
	brightness = GameState.svetik_brightness
	screen_rotation_degrees = GameState.svetik_screen_rotation_degrees


func get_chat_context(scene_root: Node) -> Dictionary:
	var room := str(scene_root.name) if scene_root != null else "unknown"
	var objects: Array[Dictionary] = []
	for room_name in ROOM_OBJECTS:
		for object_name in ROOM_OBJECTS[room_name]:
			var key := _object_key(room_name, object_name)
			var object_state: Dictionary = GameState.world_object_positions.get(key, {"room": room_name})
			objects.append({
				"room": room_name,
				"object": object_name,
				"located_in": object_state.get("room", room_name),
				"x": object_state.get("x", null),
				"y": object_state.get("y", null),
				"broken": GameState.broken_world_objects.has(key),
				"stolen": GameState.stolen_world_objects.has(key),
			})
	return {
		"room": room,
		"rooms": ROOM_NAMES,
		"objects": objects,
		"brightness": brightness,
		"screen_rotation_degrees": screen_rotation_degrees,
		"coordinate_bounds": {"x": [30, 2150], "y": [30, 850]},
	}


func apply_actions(actions: Array) -> void:
	for action in actions:
		if not action is Dictionary:
			continue
		match action.get("type", ""):
			"set_brightness":
				_set_brightness(float(action.get("value", 1.0)))
			"rotate_screen":
				_rotate_screen(float(action.get("degrees", 0.0)))
			"move_object":
				_move_object(action)
			"break_object":
				_break_object(action)
			"steal_object":
				_steal_object(action)


func restore_room(scene_root: Node) -> void:
	if scene_root == null:
		return
	call_deferred("_restore_room_deferred", scene_root)


func _restore_room_deferred(scene_root: Node) -> void:
	if not is_instance_valid(scene_root):
		return
	_set_brightness(brightness, scene_root)
	_rotate_screen(screen_rotation_degrees)
	var room := str(scene_root.name)
	var saved_positions: Dictionary = GameState.world_object_positions
	var broken: Array = GameState.broken_world_objects
	for object_name in ROOM_OBJECTS.get(room, []):
		var key := _object_key(room, object_name)
		var item := scene_root.get_node_or_null(NodePath(object_name))
		if item == null:
			continue
		var object_state: Dictionary = saved_positions.get(key, _default_object_visual(room, object_name))
		object_state.merge(_capture_object_visual(item), true)
		if not object_state.has("room"):
			object_state["room"] = room
		saved_positions[key] = object_state
		if broken.has(key) or GameState.stolen_world_objects.has(key):
			_set_item_visible(item, false)
			continue
		var should_show: bool = str(object_state.get("room", room)) == room
		_set_item_visible(item, should_show)
		if should_show and object_state.has("x") and object_state.has("y"):
			var item_2d := item as Node2D
			if item_2d != null:
				item_2d.global_position = Vector2(float(object_state.x), float(object_state.y))
	_restore_moved_proxies(scene_root)


func _set_brightness(value: float, scene_root: Node = null) -> void:
	brightness = clampf(value, 0.2, 1.8)
	GameState.svetik_brightness = brightness
	if scene_root == null:
		scene_root = get_tree().current_scene
	if scene_root == null:
		return
	var modulation := scene_root.get_node_or_null("SvetikLightModulation") as CanvasModulate
	if modulation == null:
		modulation = CanvasModulate.new()
		modulation.name = "SvetikLightModulation"
		scene_root.add_child(modulation)
	modulation.color = Color(brightness, brightness, brightness, 1.0)


func _rotate_screen(degrees: float) -> void:
	screen_rotation_degrees = fposmod(degrees, 360.0)
	GameState.svetik_screen_rotation_degrees = screen_rotation_degrees
	var camera := get_viewport().get_camera_2d()
	if camera == null and get_tree().current_scene != null:
		camera = get_tree().current_scene.find_child("Camera2D", true, false) as Camera2D
	if camera != null:
		# Camera2D игнорирует собственный поворот по умолчанию.
		camera.ignore_rotation = false
		camera.rotation_degrees = screen_rotation_degrees


func _move_object(action: Dictionary) -> void:
	var origin_room := str(action.get("room", ""))
	var object_name := str(action.get("object", ""))
	var destination_room := str(action.get("to_room", origin_room))
	if not _is_allowed_object(origin_room, object_name) or not (destination_room in ROOM_NAMES):
		return
	var x := clampf(float(action.get("x", 1000.0)), 30.0, 2150.0)
	var y := clampf(float(action.get("y", 500.0)), 30.0, 850.0)
	var key := _object_key(origin_room, object_name)
	if GameState.broken_world_objects.has(key) or GameState.stolen_world_objects.has(key):
		return
	var saved: Dictionary = GameState.world_object_positions.get(key, _default_object_visual(origin_room, object_name))
	var scene_root := get_tree().current_scene
	if scene_root != null and str(scene_root.name) == origin_room:
		var source := scene_root.get_node_or_null(NodePath(object_name))
		if source != null:
			saved.merge(_capture_object_visual(source), true)
	saved["room"] = destination_room
	saved["x"] = x
	saved["y"] = y
	GameState.world_object_positions[key] = saved
	if scene_root != null:
		var item := scene_root.get_node_or_null(NodePath(object_name))
		if item != null:
			if str(scene_root.name) == destination_room:
				var item_2d := item as Node2D
				if item_2d != null:
					item_2d.global_position = Vector2(x, y)
				_set_item_visible(item, true)
			else:
				_set_item_visible(item, false)
		_restore_moved_proxies(scene_root)


func _break_object(action: Dictionary) -> void:
	var room := str(action.get("room", ""))
	var object_name := str(action.get("object", ""))
	if not _is_allowed_object(room, object_name):
		return
	var key := _object_key(room, object_name)
	if GameState.stolen_world_objects.has(key):
		return
	if not GameState.broken_world_objects.has(key):
		GameState.broken_world_objects.append(key)
	var scene_root := get_tree().current_scene
	if scene_root != null:
		var item := scene_root.get_node_or_null(NodePath(object_name))
		if item != null:
			_animate_item_removal(item)


func _steal_object(action: Dictionary) -> void:
	var room := str(action.get("room", ""))
	var object_name := str(action.get("object", ""))
	if not _is_allowed_object(room, object_name):
		return
	var key := _object_key(room, object_name)
	if GameState.broken_world_objects.has(key) or GameState.stolen_world_objects.has(key):
		return
	GameState.stolen_world_objects.append(key)
	var object_state: Dictionary = GameState.world_object_positions.get(key, _default_object_visual(room, object_name))
	object_state["stolen"] = true
	GameState.world_object_positions[key] = object_state
	var scene_root := get_tree().current_scene
	if scene_root != null:
		var item := scene_root.get_node_or_null(NodePath(object_name))
		if item != null:
			_animate_item_removal(item)


func _animate_item_removal(item: Node) -> void:
	if item is Area2D:
		item.monitoring = false
		item.monitorable = false
	if item is CanvasItem:
		var tween := item.create_tween()
		tween.set_parallel(true)
		var item_2d := item as Node2D
		if item_2d != null:
			tween.tween_property(item_2d, "scale", item_2d.scale * 0.08, 0.3)
		tween.tween_property(item, "modulate:a", 0.0, 0.3)
		tween.finished.connect(func(): _set_item_visible(item, false))
	else:
		_set_item_visible(item, false)


func _set_item_visible(item: Node, should_show: bool) -> void:
	if item is CanvasItem:
		item.visible = should_show
	if item is Area2D:
		item.monitoring = should_show
		item.monitorable = should_show


func _restore_moved_proxies(scene_root: Node) -> void:
	var room := str(scene_root.name)
	for origin_room in ROOM_OBJECTS:
		for object_name in ROOM_OBJECTS[origin_room]:
			if origin_room == room:
				continue
			var key := _object_key(origin_room, object_name)
			if GameState.broken_world_objects.has(key) or GameState.stolen_world_objects.has(key):
				continue
			var object_state: Dictionary = GameState.world_object_positions.get(key, {})
			if object_state.get("room", origin_room) != room:
				continue
			if scene_root.get_node_or_null(NodePath(object_name)) != null:
				continue
			var proxy := Area2D.new()
			proxy.name = object_name
			proxy.set_script(MOVED_OBJECT_SCRIPT)
			proxy.set("interaction_name", object_name)
			proxy.set("interaction_action", "Осмотреть")
			proxy.scale = Vector2(
				float(object_state.get("root_scale_x", 1.0)),
				float(object_state.get("root_scale_y", 1.0))
			)
			var sprite := Sprite2D.new()
			var texture_path := str(object_state.get("texture_path", ""))
			if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
				continue
			sprite.texture = load(texture_path)
			sprite.scale = Vector2(
				float(object_state.get("sprite_scale_x", 1.0)),
				float(object_state.get("sprite_scale_y", 1.0))
			)
			sprite.position = Vector2(
				float(object_state.get("sprite_x", 0.0)),
				float(object_state.get("sprite_y", 0.0))
			)
			proxy.add_child(sprite)
			var collision := CollisionShape2D.new()
			collision.position = Vector2(
				float(object_state.get("shape_x", 0.0)),
				float(object_state.get("shape_y", 0.0))
			)
			if object_state.get("shape_type", "") == "CircleShape2D":
				var circle := CircleShape2D.new()
				circle.radius = float(object_state.get("shape_radius", 40.0))
				collision.shape = circle
			else:
				var rectangle := RectangleShape2D.new()
				rectangle.size = Vector2(
					float(object_state.get("shape_width", 80.0)),
					float(object_state.get("shape_height", 80.0))
				)
				collision.shape = rectangle
			proxy.add_child(collision)
			scene_root.add_child(proxy)
			proxy.global_position = Vector2(float(object_state.get("x", 1000.0)), float(object_state.get("y", 500.0)))


func _capture_object_visual(item: Node) -> Dictionary:
	var data: Dictionary = {}
	var sprite := item.find_child("Sprite2D", true, false) as Sprite2D
	if sprite != null and sprite.texture != null:
		data["texture_path"] = sprite.texture.resource_path
		data["root_scale_x"] = item.scale.x if item is Node2D else 1.0
		data["root_scale_y"] = item.scale.y if item is Node2D else 1.0
		data["sprite_scale_x"] = sprite.scale.x
		data["sprite_scale_y"] = sprite.scale.y
		data["sprite_x"] = sprite.position.x
		data["sprite_y"] = sprite.position.y
	var collision := item.find_child("CollisionShape2D", true, false) as CollisionShape2D
	if collision != null and collision.shape != null:
		data["shape_x"] = collision.position.x
		data["shape_y"] = collision.position.y
		if collision.shape is CircleShape2D:
			data["shape_type"] = "CircleShape2D"
			data["shape_radius"] = collision.shape.radius
		elif collision.shape is RectangleShape2D:
			data["shape_type"] = "RectangleShape2D"
			data["shape_width"] = collision.shape.size.x
			data["shape_height"] = collision.shape.size.y
	return data


func _is_allowed_object(room: String, object_name: String) -> bool:
	return ROOM_OBJECTS.has(room) and object_name in ROOM_OBJECTS[room]


func _default_object_visual(room: String, object_name: String) -> Dictionary:
	var defaults: Dictionary = OBJECT_VISUAL_DEFAULTS.get(_object_key(room, object_name), {}).duplicate()
	defaults["root_scale_x"] = 1.0
	defaults["root_scale_y"] = 1.0
	return defaults


func _object_key(room: String, object_name: String) -> String:
	return room + "/" + object_name
