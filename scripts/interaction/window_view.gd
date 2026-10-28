
extends Area2D

@onready var bedroom = get_parent()
@onready var window_view: Control = bedroom.get_node("UILayer/WindowView")

var is_viewing: bool = false


func _ready() -> void:
	window_view.hide()


func interact() -> void:
	if is_viewing:
		close_view()
	else:
		open_view()


func open_view() -> void:
	is_viewing = true
	window_view.show()


func close_view() -> void:
	is_viewing = false
	window_view.hide()
