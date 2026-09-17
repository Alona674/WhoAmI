extends CharacterBody2D

@export var speed: float = 300.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea

var front_texture = preload("res://art/characters/Michael_front.png")
var back_texture = preload("res://art/characters/Michael_backside.png")
var left_texture = preload("res://art/characters/Michael_left.png")
var right_texture = preload("res://art/characters/Michael_right.png")


func _physics_process(_delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")

	velocity.x = direction * speed
	velocity.y = 0

	move_and_slide()

	if direction < 0:
		sprite.texture = left_texture
	elif direction > 0:
		sprite.texture = right_texture
	else:
		sprite.texture = front_texture


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		var objects := interaction_area.get_overlapping_areas()

		if objects.size() > 0:
			var nearest_object = objects[0]
			var nearest_distance := global_position.distance_to(nearest_object.global_position)

			for object in objects:
				var distance := global_position.distance_to(object.global_position)

				if distance < nearest_distance:
					nearest_object = object
					nearest_distance = distance

			if nearest_object.has_method("interact"):
				nearest_object.interact()
