extends Node2D

@onready var dialogue_manager = $DialogueManager
@onready var player = $Player
# Переменная для отслеживания прогресса на кухне
var scene_stage: int = 0

# Флаг, чтобы сундук можно было открыть только один раз
var chest_opened: bool = false

func _ready() -> void:
	SvetikWorld.restore_room(self)
	scene_stage = 1 if GameState.get_flag("kitchen_scales_inspected") else 0
	chest_opened = GameState.get_flag("kitchen_chest_opened")
	if GameState.next_spawn_point != "":
		var spawn_point = get_node_or_null(GameState.next_spawn_point)
		if spawn_point != null:
			player.global_position = spawn_point.global_position
		GameState.next_spawn_point = ""

# --- Логика взаимодействия с предметами ---

# Вызывается из scales.gd при нажатии E
func scales_interacted() -> void:
	if not _can_interact():
		return
		
	scene_stage = 1
	GameState.set_flag("kitchen_scales_inspected")
	dialogue_manager.show_dialogue(
		"Михаил",
		"Старые весы. Стрелка застыла на странном числе..."
	)

# Вызывается из chest.gd при нажатии E
func chest_interacted() -> void:
	if not _can_interact():
		return
	if chest_opened:
		dialogue_manager.show_dialogue("Михаил", "Хлебница пуста.")
		return
		
	chest_opened = true
	GameState.set_flag("kitchen_chest_opened")
	dialogue_manager.show_dialogue(
		"Михаил",
		"В хлебнице лежит старый ключ. Интересно, от чего он?"
	)

# Вызывается из jug.gd при нажатии E
func jug_interacted() -> void:
	if not _can_interact():
		return
	dialogue_manager.show_dialogue(
		"Михаил",
		"В кувшине стоят свежие ромашки. Они пахнут домом."
	)

# Вызывается из pan.gd при нажатии E
func pan_interacted() -> void:
	if not _can_interact():
		return
	dialogue_manager.show_dialogue(
		"Михаил",
		"Тяжелая чугунная сковорода. На ней явно готовили что-то вкусное."
	)


func _can_interact() -> bool:
	return player.can_move and not get_tree().paused and not dialogue_manager.is_open and not dialogue_manager.closing


#  Логика паузы  

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		var pause_menu = get_node_or_null("UILayer/PauseMenu")
		if pause_menu == null:
			return

		pause_menu.visible = not pause_menu.visible
		player.interaction_prompt.hide_prompt()
		get_tree().paused = pause_menu.visible

		get_viewport().set_input_as_handled()


func _on_continuebutton_pressed() -> void:
	get_tree().paused = false

	var pause_menu = get_node_or_null("UILayer/PauseMenu")
	if pause_menu != null:
		pause_menu.visible = false
