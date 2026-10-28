
extends InteractableBase

@onready var dialogue_manager = get_node("../DialogueManager")

var can_interact: bool = false

# Настройки плавного полёта
var follow_target: Node2D = null
var follow_enabled: bool = false
var follow_speed: float = 3.0
var float_height: float = 12.0
var float_frequency: float = 2.5
var float_time: float = 0.0
var follow_offset: Vector2 = Vector2(65, -65)


func _ready() -> void:
	interaction_name = "Светик"


func interact() -> void:
	if not can_interact:
		return

	dialogue_manager.show_dialogue(
		"Светик",
		"Доброе утро, Михаил."
	)


func start_follow(target: Node2D) -> void:
	follow_target = target
	follow_enabled = true


func _process(delta: float) -> void:
	if not follow_enabled:
		return

	if not is_instance_valid(follow_target):
		return

	float_time += delta

	var float_offset := Vector2(
		0.0,
		sin(float_time * float_frequency) * float_height
	)

	var target_position: Vector2 = (
		follow_target.global_position
		+ follow_offset
		+ float_offset
	)

	var weight: float = 1.0 - exp(-follow_speed * delta)

	global_position = global_position.lerp(target_position, weight)
