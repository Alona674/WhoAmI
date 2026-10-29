extends "res://scripts/player/player.gd"


func _physics_process(delta: float) -> void:
	if get_parent().busy:
		can_move = false
	super._physics_process(delta)
	# Apply after the shared controller chooses its idle/walking texture.
	# This also keeps the back view throughout the mirror dialogue.
	if current_interactable == get_parent().get_node("Mirror") and is_zero_approx(velocity.x):
		sprite.texture = back_texture
