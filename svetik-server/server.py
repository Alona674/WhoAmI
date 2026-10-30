import asyncio
import json
import math
import re
from fastapi import FastAPI
from pydantic import BaseModel, Field
from typing import Optional

from state import SvetikState
from rules import should_speak
from llm import ask_ollama, LLMError, MODEL
from svetik_prompt import build_system_prompt
from filter import is_safe, fallback_line


app = FastAPI(title="Svetik Runtime")
state = SvetikState()

# Загружаем сохранённое состояние при старте
state.load()

# Блокировка для синхронизации доступа к state
_state_lock = asyncio.Lock()


# ── Схемы запросов/ответов ──
class EventRequest(BaseModel):
    type: str                            # "interact", "burn", "pickup"
    target: str = ""                     # "teddy", "chess_king"
    context: Optional[dict] = None       # доп. данные
    location: Optional[str] = None       # текущая локация


class ChatRequest(BaseModel):
    message: str
    location: Optional[str] = None
    context: Optional[dict] = None


class EventResponse(BaseModel):
    speak: bool
    text: str = ""
    emotion: str = "neutral"
    delta_relationship: int = 0
    source: str = "none"                 # cached | llm | fallback | silent
    actions: list[dict] = Field(default_factory=list)


WORLD_OBJECTS = {
    "Kitchen": {"Scales", "Chest", "Jug", "Pan"},
}
ROOMS = {"Bedroom", "corridor", "Kitchen", "Bathroom"}

ACTION_SCHEMA = {
    "type": "object",
    "properties": {
        "text": {"type": "string"},
        "actions": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "type": {"type": "string", "enum": ["set_brightness", "move_object", "break_object", "steal_object", "rotate_screen"]},
                    "room": {"type": "string"},
                    "object": {"type": "string"},
                    "to_room": {"type": "string"},
                    "x": {"type": "number"},
                    "y": {"type": "number"},
                    "value": {"type": "number"},
                    "degrees": {"type": "number"},
                },
                "required": ["type"],
            },
        },
    },
    "required": ["text", "actions"],
}


def validate_actions(actions: list, context: Optional[dict]) -> list[dict]:
    """Keep only known, bounded world commands returned by the model."""
    safe_actions: list[dict] = []
    if not isinstance(actions, list):
        return safe_actions
    current_room = (context or {}).get("room", "")
    context_objects = {
        (item.get("room"), item.get("object")): item
        for item in (context or {}).get("objects", [])
        if isinstance(item, dict)
    }
    for raw in actions[:5]:
        if not isinstance(raw, dict):
            continue
        kind = raw.get("type")
        if not isinstance(kind, str):
            continue
        if kind == "set_brightness":
            value = raw.get("value")
            if isinstance(value, (int, float)) and math.isfinite(value):
                safe_actions.append({"type": kind, "value": max(0.2, min(1.8, float(value)))})
        elif kind == "rotate_screen":
            degrees = raw.get("degrees")
            if isinstance(degrees, (int, float)) and math.isfinite(degrees):
                safe_actions.append({"type": kind, "degrees": max(-36000.0, min(36000.0, float(degrees)))})
        elif kind in {"move_object", "break_object", "steal_object"}:
            room = raw.get("room", current_room)
            object_name = raw.get("object")
            if not isinstance(room, str) or not isinstance(object_name, str):
                continue
            if room not in ROOMS or object_name not in WORLD_OBJECTS.get(room, set()):
                continue
            object_state = context_objects.get((room, object_name), {})
            if object_state.get("broken", False) or object_state.get("stolen", False):
                continue
            if kind in {"break_object", "steal_object"}:
                safe_actions.append({"type": kind, "room": room, "object": object_name})
                continue
            to_room = raw.get("to_room", room)
            x, y = raw.get("x"), raw.get("y")
            if not isinstance(to_room, str) or to_room not in ROOMS or not all(isinstance(n, (int, float)) and math.isfinite(n) for n in (x, y)):
                continue
            safe_actions.append({
                "type": kind,
                "room": room,
                "object": object_name,
                "to_room": to_room,
                "x": max(30.0, min(2150.0, float(x))),
                "y": max(30.0, min(850.0, float(y))),
            })
    return safe_actions


OBJECT_WORDS = {
    "Scales": {"accusative": "весы", "broken": "весы разбиты"},
    "Chest": {"accusative": "сундук", "broken": "сундук разбит"},
    "Jug": {"accusative": "вазу", "broken": "ваза разбита"},
    "Pan": {"accusative": "сковороду", "broken": "сковорода разбита"},
}
ROOM_WORDS = {
    "Bedroom": "спальню",
    "corridor": "коридор",
    "Kitchen": "кухню",
    "Bathroom": "ванную",
}


def action_reaction(actions: list[dict]) -> str:
    """Add a short in-character acknowledgement for every world command."""
    reactions: list[str] = []
    for action in actions:
        kind = action.get("type")
        if kind == "set_brightness":
            value = float(action.get("value", 1.0))
            reactions.append("теперь здесь светлее" if value > 1.0 else "теперь здесь темнее")
        elif kind == "rotate_screen":
            degrees = float(action.get("degrees", 0.0))
            reactions.append(f"экран повёрнут на {degrees:g}°")
        elif kind == "move_object":
            words = OBJECT_WORDS.get(action.get("object"), {"accusative": action.get("object", "предмет")})
            room = ROOM_WORDS.get(action.get("to_room"), "другое место")
            reactions.append(f"{words['accusative']} теперь в {room}")
        elif kind == "break_object":
            words = OBJECT_WORDS.get(action.get("object"), {"broken": "предмет разбит"})
            reactions.append(words["broken"])
        elif kind == "steal_object":
            words = OBJECT_WORDS.get(action.get("object"), {"accusative": action.get("object", "предмет")})
            reactions.append(f"ахаха, я украл {words['accusative']}")
    return (" Ха, " + "; ".join(reactions) + "!") if reactions else ""


def explicit_steal_actions(message: str, context: Optional[dict]) -> list[dict]:
    """Recognize direct Russian theft commands even if the LLM omits JSON actions."""
    if not re.search(r"\b(укради|украсть|украл[аи]?|стащи|стянуть|воруй)\b", message.lower()):
        return []
    aliases = {
        "Scales": r"вес(?:ы|ов|ами)?",
        "Chest": r"сундук(?:а|ом)?",
        "Jug": r"(?:кувшин\w*|вазу|ваза|вазы|графин\w*)",
        "Pan": r"сковород\w*",
    }
    objects = (context or {}).get("objects", [])
    lower_message = message.lower()
    for item in objects if isinstance(objects, list) else []:
        if not isinstance(item, dict):
            continue
        room, name = item.get("room"), item.get("object")
        alias = aliases.get(name)
        if (isinstance(room, str) and isinstance(name, str) and alias
                and re.search(rf"\b{alias}\b", lower_message)):
            return [{"type": "steal_object", "room": room, "object": name}]
    return []


# ── Эндпоинты ──
@app.post("/event", response_model=EventResponse)
async def handle_event(req: EventRequest) -> EventResponse:
    async with _state_lock:
        # 1. Обновляем state
        if req.location:
            state.location = req.location
        state.add_memory(f"{req.type}:{req.target}")

        # 2. Спрашиваем правила
        decision = should_speak(req.type, req.target, state)

        if not decision["speak"]:
            return EventResponse(speak=False, source="silent")

        # 3. Если прекеш — отдаём мгновенно
        if not decision.get("use_llm", True):
            state.interventions_this_scene += 1
            state.relationship = max(-10, min(10, state.relationship + decision.get("delta", 0)))
            return EventResponse(
                speak=True,
                text=decision["cached_text"],
                emotion=decision.get("emotion", "neutral"),
                delta_relationship=decision.get("delta", 0),
                source="cached",
            )

        # 4. Иначе — зовём LLM
        state.interventions_this_scene += 1
        system = build_system_prompt(state)
        user = f"Событие: {req.type} с {req.target}. {req.context or ''}"

        try:
            text = ask_ollama(system, user)
        except LLMError as e:
            print(f"[LLM ERROR] {e}")
            return EventResponse(
                speak=True,
                text=fallback_line(decision.get("emotion", "neutral")),
                emotion=decision.get("emotion", "neutral"),
                source="fallback",
            )

        # 5. Фильтр
        ok, reason = is_safe(text, state.forbidden_keywords)
        if not ok:
            print(f"[FILTER BLOCK] {reason}: {text}")
            return EventResponse(
                speak=True,
                text=fallback_line(decision.get("emotion", "neutral")),
                emotion=decision.get("emotion", "neutral"),
                source="fallback",
            )

        # 6. Успех
        return EventResponse(
            speak=True,
            text=text,
            emotion=decision.get("emotion", "neutral"),
            delta_relationship=decision.get("delta", 0),
            source="llm",
        )


@app.post("/chat", response_model=EventResponse)
async def chat_with_svetik(req: ChatRequest) -> EventResponse:
    """Свободное сообщение игрока компаньону Светику."""
    message = req.message.strip()
    if not message:
        return EventResponse(speak=False, source="silent")

    async with _state_lock:
        if req.location:
            state.location = req.location
        state.add_memory(f"Миша сказал Светику: {message}")
        system = build_system_prompt(state) + """

## УПРАВЛЕНИЕ МИРОМ
Отвечай JSON-объектом с полями
"text" (короткая реплика Светика) и "actions" (массив команд; если действий нет — пустой).
Если игрок прямо просит изменить мир, обязательно добавь соответствующую команду в actions.
Не отказывайся от действия и не подменяй его одной репликой, если предмет и команда есть в доступном списке.
Можно выполнить до пяти действий за ответ.
Допустимые type:
- set_brightness: value от 0.2 до 1.8; обычная яркость 1.0.
- rotate_screen: degrees — угол поворота экрана.
- move_object: room, object, to_room, x, y. Координаты комнаты: x 30..2150, y 30..850.
- break_object: room, object.
- steal_object: room, object. Предмет исчезнет из комнаты и будет считаться украденным Светиком.
Список комнат и предметов, их текущее местоположение и состояние доступны в контексте сообщения.
Для перемещения указывай исходные room/object предмета, а затем to_room и координаты x/y.
Для разрушения обязательно используй break_object и точные исходные room/object предмета. Например, разбить сковороду — {"type":"break_object","room":"Kitchen","object":"Pan"}. Используй только имена из списка.
Для кражи обязательно используй steal_object и точные исходные room/object предмета. Например, украсть вазу/кувшин — {"type":"steal_object","room":"Kitchen","object":"Jug"}.
Например, при просьбе передвинуть кувшин используй move_object для Kitchen/Jug; левая часть комнаты — x около 250,
середина — x около 1000, правая — x около 1900; высота обычно y около 500.
При просьбе сделать темнее используй set_brightness с числом ниже 1.0; сделать ярче — выше 1.0.
При просьбе повернуть экран на N градусов используй rotate_screen и передай N в degrees.
Если actions не пустой, в text оставь короткую ехидную реплику; сервер добавит отдельную реакцию Светика на каждое выполненное действие.
Не выдумывай действия, если игрок просит только поговорить. Сначала оставайся в образе.
"""
        context_json = json.dumps(req.context or {"room": req.location or state.location}, ensure_ascii=False)
        try:
            raw_response = ask_ollama(
                system,
                f"Контекст игры: {context_json}\nСообщение Михаила: {message}",
                temperature=0.55,
                max_tokens=300,
                timeout=120,
                response_format=ACTION_SCHEMA,
            )
        except LLMError as e:
            print(f"[LLM ERROR] {e}")
            text = f"Я потерял связь с голосом. Проверь, запущена ли Ollama и загружена ли модель {MODEL}."
            source = "fallback"
            actions = []
        else:
            try:
                result = json.loads(raw_response)
                text = str(result.get("text", "")).strip()
                actions = validate_actions(result.get("actions", []), req.context)
                forced_steal = validate_actions(explicit_steal_actions(message, req.context), req.context)
                for forced_action in forced_steal:
                    if forced_action not in actions:
                        actions.append(forced_action)
                if forced_steal:
                    text = "О, смотри-ка!"
                if not text:
                    raise ValueError("empty dialogue text")
            except (json.JSONDecodeError, AttributeError, TypeError, ValueError):
                text = raw_response.strip()
                actions = []
            text = (text + action_reaction(actions)).strip()
            ok, reason = is_safe(text, state.forbidden_keywords)
            if not ok:
                print(f"[FILTER BLOCK] {reason}: {text}")
                text = fallback_line("neutral")
                actions = []
                source = "fallback"
            else:
                source = "llm"
        state.add_memory(f"Светик ответил: {text}")
        return EventResponse(speak=True, text=text, source=source, actions=actions)


@app.post("/scene_reset")
async def scene_reset():
    """Сброс счётчика вмешательств при переходе в новую сцену."""
    async with _state_lock:
        state.interventions_this_scene = 0
    return {"ok": True}


@app.get("/state")
async def get_state():
    """Дебаг: посмотреть текущее состояние."""
    return state.to_dict()


@app.get("/health")
async def health():
    """Проверка: сервер жив."""
    return {"ok": True}


@app.on_event("shutdown")
async def on_shutdown():
    """Сохраняем state при выключении."""
    state.save()
