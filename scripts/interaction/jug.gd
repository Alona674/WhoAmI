extends Area2D

func _on_body_entered(body):
    if body.name == "Player":
        var dm = get_tree().current_scene.get_node("DialogueManager")
        if dm: dm.start_dialogue("В кувшине стоят свежие ромашки. Они пахнут домом.")
