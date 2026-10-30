def is_safe(text: str, forbidden: list) -> tuple[bool, str]:
    """
    Возвращает (ok, reason).
    ok=False — ответ надо выкинуть и заменить на fallback.
    """
    lower = text.lower()
    for kw in forbidden:
        if kw.lower() in lower:
            return False, f"forbidden: {kw}"
    return True, "ok"


def fallback_line(emotion: str = "neutral") -> str:
    """Что сказать если LLM выдал мусор."""
    lines = {
        "smug": "Ха. Ну и ну.",
        "angry": "Отстань.",
        "soft": "...проехали.",
        "neutral": "Я на секунду задумался.",
    }
    return lines.get(emotion, "Хм.")
