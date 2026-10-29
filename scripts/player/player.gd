
extends CharacterBody2D

@export var speed: float = 300.0
var can_move: bool = true

# Границы, в которых может ходить Михаил
@export var left_limit: float = -330.0
@export var right_limit: float = 2100.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea

var interaction_prompt: Control
var interaction_prompt_instance: Control
var current_interactable: Area2D = null
var highlighted_interactable: Area2D = null

var front_texture = preload("res://art/characters/Michael_front.png")
var back_texture = preload("res://art/characters/Michael_backside.png")
var left_texture = preload("res://art/characters/Michael_left.png")
var right_texture = preload("res://art/characters/Michael_right.png")



func _ready() -> void:
	var prompt_scene = preload("res://scenes/ui/interaction_prompt.tscn")
	interaction_prompt_instance = prompt_scene.instantiate()
	interaction_prompt = interaction_prompt_instance

	var current_scene = get_tree().current_scene

	if current_scene == null:
		return

	var ui_layer = current_scene.find_child("InteractionUI", true, false)

	if ui_layer != null:
		ui_layer.add_child.call_deferred(interaction_prompt_instance)
	else:
		current_scene.add_child.call_deferred(interaction_prompt_instance)

	interaction_prompt.hide()

	if not GameState.has_pending_player_position:
		return

	if current_scene.scene_file_path != GameState.saved_scene:
		return

	global_position = GameState.saved_player_position
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
	if event.is_action_pressed("interact") and not event.is_echo():
		if current_interactable != null:
			if current_interactable.has_method("interact"):
				current_interactable.interact()




func _update_interaction_target() -> void:
	var objects := interaction_area.get_overlapping_areas()
	var nearest_object: Area2D = null
	var nearest_distance: float = INF

	for object in objects:
		if not object.has_method("interact"):
			continue

		var distance := global_position.distance_to(
			object.global_position
		)

		if distance < nearest_distance:
			nearest_object = object
			nearest_distance = distance

	current_interactable = nearest_object
	highlighted_interactable = nearest_object

	if interaction_prompt == null:
		return

	if not is_instance_valid(interaction_prompt):
		return

	if not interaction_prompt.is_inside_tree():
		return

	if current_interactable == null:
		interaction_prompt.hide_prompt()
		return

	var object_name: String = str(
		current_interactable.get("interaction_name")
	)

	var action_name: String = str(
		current_interactable.get("interaction_action")
	)

	interaction_prompt.show_prompt(object_name, action_name)

	var target_position: Vector2 = current_interactable.get_global_transform_with_canvas().origin

	interaction_prompt.position = target_position + Vector2(-50, -100)
