class_name InteractableBase
extends Area2D

@export var interaction_name: String = "Объект"

func interact() -> void:
	print("Взаимодействие: ", interaction_name)
