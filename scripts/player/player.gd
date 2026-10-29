
extends CharacterBody2D

@export var speed: float = 300.0
@export var room_controls_prompt: bool = false
var can_move: bool = true

# Границы, в которых может ходить Михаил
@export var left_limit: float = 95.0
@export var right_limit: float = 2075.0
# Player.position is the feet position in every room.
@export var floor_y: float = 630.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var interaction_prompt: Label = get_tree().current_scene.find_child("InteractionPrompt", true, false) as Label
var current_interactable: Area2D = null
var highlighted_interactable: Area2D = null

var front_texture = preload("res://art/characters/Michael_front.png")
var back_texture = preload("res://art/characters/Michael_backside.png")
var left_texture = preload("res://art/characters/Michael_left.png")
var right_texture = preload("res://art/characters/Michael_right.png")


func _ready() -> void:
	global_position.y = floor_y
	if not GameState.has_pending_player_position:
		return

	var current_scene = get_tree().current_scene

	if current_scene == null:
		return

	if current_scene.scene_file_path != GameState.saved_scene:
		return

	global_position = GameState.saved_player_position
	# Older saves used a sprite-origin position instead of the floor anchor.
	global_position.y = floor_y
	GameState.has_pending_player_position = false


func _physics_process(_delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction := Input.get_axis("move_left", "move_right")

	velocity.x = direction * speed
	velocity.y = 0

	move_and_slide()

	# Не даём Михаилу выйти за границы комнаты
	global_position.x = clamp(
		global_position.x,
		left_limit,
		right_limit
	)

	# Меняем направление взгляда
	if direction < 0:
		sprite.texture = left_texture
	elif direction > 0:
		sprite.texture = right_texture
	else:
		sprite.texture = front_texture
	
	_update_interaction_target()



func _input(event: InputEvent) -> void:
	if not can_move:
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		if current_interactable != null:
			if current_interactable.has_method("interact"):
				current_interactable.interact()


func _update_interaction_target() -> void:
	var objects := interaction_area.get_overlapping_areas()
	var nearest_object: Area2D = null
	var nearest_distance: float = INF

	for object in objects:
		if not object.is_visible_in_tree() or not object.has_method("interact"):
			continue

		var distance := global_position.distance_to(
			object.global_position
		)

		if distance < nearest_distance:
			nearest_object = object
			nearest_distance = distance

	highlighted_interactable = nearest_object
	current_interactable = nearest_object

	if interaction_prompt == null or room_controls_prompt:
		return

	if current_interactable != null:
		var object_name: String = str(
			current_interactable.get("interaction_name")
		)
		interaction_prompt.text = "E — Осмотреть " + object_name
		interaction_prompt.show()
	else:
		interaction_prompt.hide()
