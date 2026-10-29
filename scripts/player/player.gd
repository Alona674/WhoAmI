
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
var interaction_prompt: InteractionPrompt
var current_interactable: Area2D = null
var highlighted_interactable: Area2D = null

var front_texture = preload("res://art/characters/Michael_front.png")
var back_texture = preload("res://art/characters/Michael_backside.png")
var left_texture = preload("res://art/characters/Michael_left.png")
var right_texture = preload("res://art/characters/Michael_right.png")


func _ready() -> void:
	global_position.y = floor_y
	var current_scene = get_parent()
	interaction_prompt = current_scene.find_child("InteractionPrompt", true, false) as InteractionPrompt
	if interaction_prompt == null:
		interaction_prompt = preload("res://scenes/ui/interaction_prompt.tscn").instantiate() as InteractionPrompt
		var ui_layer = current_scene.get_node_or_null("InteractionUI")
		if ui_layer == null:
			ui_layer = current_scene.get_node_or_null("UILayer")
		if ui_layer == null:
			ui_layer = CanvasLayer.new()
			ui_layer.name = "InteractionUI"
			current_scene.add_child.call_deferred(ui_layer)
		ui_layer.add_child.call_deferred(interaction_prompt)
	interaction_prompt.hide()

	if not GameState.has_pending_player_position:
		return

	if current_scene.scene_file_path != GameState.saved_scene:
		return

	global_position = GameState.saved_player_position
	# Older saves used a sprite-origin position instead of the floor anchor.
	global_position.y = floor_y
	GameState.has_pending_player_position = false


func _physics_process(_delta: float) -> void:
	if not can_move:
		interaction_prompt.hide()
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
		# Leave E to the door handler when standing in a doorway.
		for object in interaction_area.get_overlapping_areas():
			if object.has_method("interact_with_door") and object.player_nearby:
				return
		if current_interactable != null:
			if current_interactable.has_method("interact"):
				current_interactable.interact()


func _update_interaction_target() -> void:
	var objects := interaction_area.get_overlapping_areas()
	var nearest_object: Area2D = null
	var nearest_distance: float = INF
	var nearest_priority: int = -2147483648

	for object in objects:
		if not object.is_visible_in_tree() or not object.has_method("interact"):
			continue
		if object.has_method("interact_with_door") and not object.player_nearby:
			continue

		var distance := global_position.distance_to(
			object.global_position
		)

		var priority: int = object.interaction_priority if object is InteractableBase else 0
		# A nearby companion must not take E away from room objects.
		if priority > nearest_priority or (priority == nearest_priority and distance < nearest_distance):
			nearest_object = object
			nearest_distance = distance
			nearest_priority = priority

	highlighted_interactable = nearest_object
	current_interactable = nearest_object

	if room_controls_prompt:
		return

	show_interaction_prompt(current_interactable)


func show_interaction_prompt(target: Area2D, object_name: String = "", action_name: String = "") -> void:
	if not is_instance_valid(interaction_prompt) or not interaction_prompt.is_node_ready():
		return
	if not is_instance_valid(target):
		interaction_prompt.hide_prompt()
		return
	if object_name.is_empty():
		object_name = str(target.get("interaction_name"))
	if action_name.is_empty():
		action_name = str(target.get("interaction_action"))
	interaction_prompt.show_prompt(object_name, action_name)
	var target_position: Vector2 = target.get_global_transform_with_canvas().origin
	interaction_prompt.position = target_position + Vector2(-50, -100)
