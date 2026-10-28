extends Area2D

@export var is_opened: bool = false

func _on_body_entered(body):
    if body.name == "Player" and Input.is_action_just_pressed("interact"):
        if not is_opened:
            print("Вы нашли предмет в сундуке!")
            is_opened = true
            # Здесь можно добавить логику добавления в инвентарь
            var dm = get_tree().current_scene.get_node("DialogueManager")
            if dm: dm.start_dialogue("В сундуке лежит старый ключ...")
