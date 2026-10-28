extends Area2D
func _ready():
    body_entered.connect(_on_body_entered)

func _on_body_entered(body):
    if body.name == "Player":
        var dm = get_tree().current_scene.get_node("DialogueManager")
        if dm: dm.start_dialogue("Тяжелая чугунная сковорода. На ней явно готовили что-то вкусное.") 
