
extends Node2D

@onready var player = $Player
@onready var walk_shape = $WalkableArea/WalkCollisionShape2D
@onready var camera: Camera2D = $Player/Camera2D
@onready var camera_shape: CollisionShape2D = $CameraArea/CameraCollisionShape2D
@onready var pause_menu = $UILayer/PauseMenu

@export var player_left_offset: float = 0.0
@export var player_right_offset: float = 0.0



func _ready() -> void:
	if GameState.next_spawn_point != "":
		var spawn_point = get_node_or_null(GameState.next_spawn_point)
		if spawn_point != null:
			player.global_position = spawn_point.global_position
		GameState.next_spawn_point = ""

	var rect = walk_shape.shape as RectangleShape2D

	if rect == null:
		return

	# Границы движения Михаила
	var half_width = rect.size.x * walk_shape.global_transform.x.length() / 2.0
	var center_x = walk_shape.global_position.x

	var left_edge = center_x - half_width
	var right_edge = center_x + half_width

	player.left_limit = left_edge + player_left_offset
	player.right_limit = right_edge - player_right_offset

	# Границы камеры из CameraArea
	var camera_rect = camera_shape.shape as RectangleShape2D

	if camera_rect == null:
		return

	var camera_half_width = camera_rect.size.x * camera_shape.global_transform.x.length() / 2.0
	var camera_center_x = camera_shape.global_position.x

	var camera_left_edge = camera_center_x - camera_half_width
	var camera_right_edge = camera_center_x + camera_half_width

	camera.limit_left = roundi(camera_left_edge)
	camera.limit_right = roundi(camera_right_edge)
	camera.limit_smoothed = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if pause_menu.visible:
			pause_menu.hide()
			get_tree().paused = false
		else:
			pause_menu.show()
			get_tree().paused = true

		get_viewport().set_input_as_handled()
