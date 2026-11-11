
extends InteractableBase

@onready var diary = get_tree().current_scene.get_node("UILayer/Diary")

func _ready() -> void:
	interaction_name = "Открыть дневник"

func interact() -> void:
	diary.toggle_diary()
