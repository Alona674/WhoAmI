extends Area2D

var player_near: bool = false


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_near = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_near = false


func interact() -> void:
	GameState.add_item("teddy")
	queue_free()
