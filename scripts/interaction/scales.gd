extends Area2D

@export var dialogue_text: String = "Старые весы. Стрелка застыла на странном числе."

func _on_body_entered(body):
    if body.name == "Player":
        # Вызов менеджера диалогов
        var dm = get_tree().current_scene.get_node("DialogueManager")
        if dm: dm.start_dialogue(dialogue_text)
