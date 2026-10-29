extends Polygon2D

@export var player_path: NodePath = NodePath("../Player/Sprite2D")
@onready var player_sprite: Sprite2D = get_node(player_path)
@onready var reflection: Sprite2D = $Reflection


func _process(_delta: float) -> void:
	# A live 2D reflection, clipped to the glass inside the painted frame.
	# The background is a flat illustration, so only the character is dynamic.
	var player = player_sprite.get_parent()
	if player_sprite.texture == player.back_texture:
		reflection.texture = player.front_texture
	elif player_sprite.texture == player.front_texture:
		reflection.texture = player.back_texture
	else:
		reflection.texture = player_sprite.texture
	reflection.flip_h = not player_sprite.flip_h
	reflection.global_scale = player_sprite.global_scale * 0.85
	reflection.global_position = Vector2(player_sprite.global_position.x, 360.0)
