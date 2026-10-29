extends InteractableBase

@onready var window_view: Control = get_parent().get_node("UILayer/WindowView")
@onready var player = get_parent().get_node("Player")

func _ready() -> void:
	interaction_name = "Посмотреть в окно"
	window_view.hide()

func interact() -> void:
	window_view.show()
	player.can_move = false
	get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if window_view.visible and not event.is_echo() and (event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel")):
		window_view.hide()
		player.can_move = true
		get_viewport().set_input_as_handled()
