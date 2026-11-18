
extends Control

@onready var story_text: RichTextLabel = $StoryText
@onready var continue_hint: Label = $ContinueHint
@onready var fade: ColorRect = $Fade

var current_page: int = 0
var transitioning: bool = false

var intro_pages: Array[String] = [
    "Всё начинается с воспоминаний...\n\nИногда самые обычные вещи хранят в себе истории, о которых мы давно забыли.",
    "Некоторые истории начинаются задолго до своего начала...\n\nЗа привычными событиями могут скрываться тайны, которые ждут своего часа.",
    "И у каждой тайны есть свой хранитель...\n\nТот, кто знает больше, чем кажется. Тот, кто может помочь найти ответы.",
    "Но это уже другая история...\n\nВ одном обычном доме жила обычная семья. И однажды утром мальчик по имени Михаил проснулся, ещё не подозревая, что его жизнь скоро изменится."
]


func _ready() -> void:
    continue_hint.text = "Нажмите ПРОБЕЛ, чтобы продолжить"
    story_text.modulate.a = 1.0
    continue_hint.modulate.a = 1.0
    fade.modulate.a = 0.0
    _show_page()


func _show_page() -> void:
    story_text.text = intro_pages[current_page]


func _unhandled_input(event: InputEvent) -> void:
    if not event.is_action_pressed("ui_accept"):
        return

    if transitioning:
        return

    transitioning = true

    var tween := create_tween()
    tween.tween_property(story_text, "modulate:a", 0.0, 0.5)
    await tween.finished

    if current_page < intro_pages.size() - 1:
        current_page += 1
        _show_page()

        story_text.modulate.a = 0.0
        var appear := create_tween()
        appear.tween_property(story_text, "modulate:a", 1.0, 1.2)
        await appear.finished

        transitioning = false
    
    else:
        var fade_tween := create_tween()
        fade_tween.tween_property(fade, "modulate:a", 1.0, 1.5)
        await fade_tween.finished

        await get_tree().create_timer(1.0).timeout

        GameState.intro_fade_pending = true
        get_tree().change_scene_to_file("res://scenes/rooms/bedroom.tscn")
