extends Area2D

var player_in_area = false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Player":
		player_in_area = true

func _on_body_exited(body):
	if body.name == "Player":
		player_in_area = false

func _process(delta):
	if player_in_area and Input.is_action_just_pressed("interact"):
		# Находим главный узел комнаты и вызываем его функцию
		var room = get_tree().current_scene
		if room.has_method("scales_interacted"):
			room.scales_interacted()
