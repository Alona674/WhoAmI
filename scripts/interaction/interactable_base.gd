class_name InteractableBase
extends Area2D

@export var interaction_name: String = "Объект"
@export var interaction_action: String = "Осмотреть"
@export var interaction_priority: int = 0

func interact() -> void:
	print("Взаимодействие: ", interaction_name)
