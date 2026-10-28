
extends CharacterBody2D

@export var speed: float = 300.0
@export var left_limit: float = -330.0
@export var right_limit: float = 2100.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea

@onready var window_view: Control = get_tree().current_scene.get_node(
	"UILayer/WindowView"
)

var front_texture = preload("res://art/characters/Michael_front.png")
var back_texture = preload("res://art/characters/Michael_backside.png")
var left_texture = preload("res://art/characters/Michael_left.png")
var right_texture = preload("res://art/characters/Michael_right.png")


func _physics_process(_delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")

	velocity.x = direction * speed
	velocity.y = 0

	move_and_slide()

	global_position.x = clamp(
		global_position.x,
		left_limit,
		right_limit
	)

	if direction < 0:
		sprite.texture = left_texture
	elif direction > 0:
		sprite.texture = right_texture
	else:
		sprite.texture = front_texture


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or event.is_echo():
		return

	# Закрываем просмотр сада клавишей E.
	if window_view.visible:
		window_view.hide()
		get_viewport().set_input_as_handled()
		return

	# Закрываем окно обыска клавишей E.
	var wardrobe_panel = get_tree().current_scene.get_node_or_null(
		"UILayer/WardrobeLootPanel"
	)

	if wardrobe_panel != null and wardrobe_panel.visible:
		wardrobe_panel.close_panel()
		get_viewport().set_input_as_handled()
		return

	# Ищем ближайший объект для взаимодействия.
	var objects := interaction_area.get_overlapping_areas()

	if objects.is_empty():
		return

	var nearest_object = objects[0]
	var nearest_distance: float = global_position.distance_to(
		nearest_object.global_position
	)

	for object in objects:
		var distance: float = global_position.distance_to(
			object.global_position
		)

		if distance < nearest_distance:
			nearest_object = object
			nearest_distance = distance

	if nearest_object.has_method("interact"):
		nearest_object.interact()
		get_viewport().set_input_as_handled()
