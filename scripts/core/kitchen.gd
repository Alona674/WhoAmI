extends Node2D

@onready var dialogue_manager = $DialogueManager
@onready var player = $Player
# Переменная для отслеживания прогресса на кухне
var scene_stage: int = 0

# Флаг, чтобы сундук можно было открыть только один раз
var chest_opened: bool = false

func _ready() -> void:
	SvetikWorld.restore_room(self)
	if GameState.next_spawn_point != "":
		var spawn_point = get_node_or_null(GameState.next_spawn_point)
		if spawn_point != null:
			player.global_position = spawn_point.global_position
		GameState.next_spawn_point = ""

	dialogue_manager.dialogue_closed.connect(_on_dialogue_closed)


# --- Логика взаимодействия с предметами ---

# Вызывается из scales.gd при нажатии E
func scales_interacted() -> void:
	if scene_stage > 0: 
		return # Если уже взаимодействовали, больше не показываем
		
	scene_stage = 1
	dialogue_manager.show_dialogue(
		"Михаил",
		"Старые весы. Стрелка застыла на странном числе..."
	)

# Вызывается из chest.gd при нажатии E
func chest_interacted() -> void:
	if chest_opened:
		dialogue_manager.show_dialogue("Михаил", "Хлебница пуст.")
		return
		
	chest_opened = true
	dialogue_manager.show_dialogue(
		"Михаил",
		"В хлебнице лежит старый ключ. Интересно, от чего он?"
	)

# Вызывается из jug.gd при нажатии E
func jug_interacted() -> void:
	dialogue_manager.show_dialogue(
		"Михаил",
		"В кувшине стоят свежие ромашки. Они пахнут домом."
	)

# Вызывается из pan.gd при нажатии E
func pan_interacted() -> void:
	dialogue_manager.show_dialogue(
		"Михаил",
		"Тяжелая чугунная сковорода. На ней явно готовили что-то вкусное."
	)


#  Логика после закрытия диалогов 

func _on_dialogue_closed() -> void:
	# Здесь можно добавить развитие сюжета после определенных диалогов.
	# Например, если игрок осмотрел весы (scene_stage == 1), 
	# можно запустить какое-то событие.
	
	if scene_stage == 1:
		# Пример: после осмотра весов что-то происходит на кухне
		# start_kitchen_event()
		pass 


#  Логика паузы  

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		var pause_menu = get_node_or_null("UILayer/PauseMenu")
		if pause_menu == null:
			return

		pause_menu.visible = not pause_menu.visible
		get_tree().paused = pause_menu.visible

		get_viewport().set_input_as_handled()


func _on_continuebutton_pressed() -> void:
	get_tree().paused = false

	var pause_menu = get_node_or_null("UILayer/PauseMenu")
	if pause_menu != null:
		pause_menu.visible = false
