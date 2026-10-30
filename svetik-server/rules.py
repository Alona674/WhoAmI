from typing import Optional

CACHED_LINES = {
    ("interact", "teddy"): {
        "text": "Ха, какая рухлядь. Миша, тебе стоит завести новых друзей.",
        "emotion": "smug",
        "delta": 0,
    },
    ("burn", "chess_king"): {
        "text": "Ну ты и псих. Мне нравится.",
        "emotion": "smug",
        "delta": +2,
    },
    ("return", "chess_king"): {
        "text": "Скукота. Подчинился папочке?",
        "emotion": "angry",
        "delta": -2,
    },
    ("pickup", "salt"): {
        "text": "Ну и скукота. Я больше люблю сахар.",
        "emotion": "neutral",
        "delta": -1,
    },
    ("pickup", "sugar"): {
        "text": "Давай-давай, испорти ужин. Я в деле.",
        "emotion": "smug",
        "delta": +2,
    },
}


SILENT_TARGETS = {"mama", "papa"}
SILENT_TYPES = {"dialogue_with_parents"}


def should_speak(event_type: str, target: str, state) -> dict:
    """
    Решает: говорит Светик или молчит.
    Возвращает dict с полями: speak, reason, emotion, delta, use_llm
    """
    if target in SILENT_TARGETS:
        return {"speak": False, "reason": "parent_dialogue"}

    if event_type in SILENT_TYPES:
        return {"speak": False, "reason": "silent_type"}

    if state.interventions_this_scene >= 6:
        return {"speak": False, "reason": "intervention_limit"}

    key = (event_type, target)
    if key in CACHED_LINES:
        cached = CACHED_LINES[key]
        return {
            "speak": True,
            "reason": "cached",
            "emotion": cached["emotion"],
            "delta": cached["delta"],
            "use_llm": False,
            "cached_text": cached["text"],
        }

    return {
        "speak": True,
        "reason": "llm",
        "emotion": "neutral",
        "delta": 0,
        "use_llm": True,
    }