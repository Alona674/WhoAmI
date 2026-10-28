
extends Area2D

@export_group("Переход между комнатами")
@export_file("*.tscn") var target_scene: String = ""
@export var target_spawn_point: String = ""

@export_group("Диалог")
@export var dialogue_manager_path: NodePath = NodePath("../DialogueManager")
@export var dialogue_speaker: String = "Михаил"
@export_multiline var dialogue_text: String = ""

var player_nearby: bool = false
var interaction_in_progress: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = false


func _unhandled_input(event: InputEvent) -> void:
	if not player_nearby:
		return

	if interaction_in_progress:
		return

	if event.is_action_pressed("interact") and not event.is_echo():
		interact_with_door()


func interact_with_door() -> void:
	# Если указана сцена, переходим в неё.
	if target_scene != "":
		GameState.next_spawn_point = target_spawn_point
		get_tree().change_scene_to_file(target_scene)
		return

	# Если сцены нет, пробуем показать диалог.
	if dialogue_text.strip_edges() == "":
		return

	var dialogue_manager = get_node_or_null(dialogue_manager_path)

	if dialogue_manager == null:
		push_warning("У двери не найден DialogueManager: " + str(dialogue_manager_path))
		return

	if not dialogue_manager.has_method("show_dialogue"):
		push_warning("У DialogueManager отсутствует метод show_dialogue().")
		return

	interaction_in_progress = true
	dialogue_manager.show_dialogue(dialogue_speaker, dialogue_text)

	if dialogue_manager.has_signal("dialogue_closed"):
		await dialogue_manager.dialogue_closed

	interaction_in_progress = false
	
	
