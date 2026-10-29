extends InteractableBase

@export var follow_distance: float = 100.0
@export var flight_height: float = 310.0
@export var follow_smoothing: float = 3.0
@export var hover_amplitude: float = 12.0
@export var hover_speed: float = 2.5

@onready var dialogue_manager = get_node("../DialogueManager")
@onready var player = get_parent().get_node("Player")

var following: bool = false
var scripted: bool = false
var scripted_target: Vector2
var travel_direction: float = 1.0
var hover_phase: float = 0.0

func _ready() -> void:
	interaction_name = "Светик"
	# Let the room apply its entry marker before placing the companion.
	call_deferred("_restore_following")


func _restore_following() -> void:
	if GameState.bedroom_intro_completed:
		start_following(true)


func start_following(snap_to_player: bool = false) -> void:
	following = true
	show()
	if snap_to_player:
		global_position = _follow_target()


func _follow_target() -> Vector2:
	return Vector2(
		clampf(player.global_position.x - travel_direction * follow_distance,
			player.left_limit + 35.0, player.right_limit - 35.0),
		player.global_position.y - flight_height
	)


func _physics_process(delta: float) -> void:
	if not following and not scripted:
		return
	hover_phase = fmod(hover_phase + delta * hover_speed, TAU)
	if not is_zero_approx(player.velocity.x):
		travel_direction = signf(player.velocity.x)
	var target := scripted_target if scripted else _follow_target()
	target.y += sin(hover_phase) * hover_amplitude
	global_position = global_position.lerp(target, 1.0 - exp(-follow_smoothing * delta))


func begin_scripted_scene(target: Vector2) -> void:
	scripted_target = target
	scripted = true
	if not visible:
		global_position = target
	show()


func end_scripted_scene() -> void:
	scripted = false
	visible = following


func interact() -> void:
	dialogue_manager.show_dialogue(
		"Светик",
		"Доброе утро, Михаил."
	)
