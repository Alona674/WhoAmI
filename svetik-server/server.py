import asyncio
import json
import math
import re
import os
import torch
from fastapi import FastAPI
from pydantic import BaseModel, Field
from typing import Optional
import gc
import time
from rembg import remove


# Подключаем библиотеки генерации картинок
from diffusers import AutoPipelineForText2Image

from state import SvetikState
from rules import should_speak
from llm import ask_ollama, LLMError, MODEL
from svetik_prompt import build_system_prompt
from filter import is_safe, fallback_line


app = FastAPI(title="Svetik Runtime с ИИ-Режиссером")
state = SvetikState()

# Загружаем сохранённое состояние при старте
state.load()

# Блокировка для синхронизации доступа к state
_state_lock = asyncio.Lock()


# Изначально модель пустая и не занимает оперативную память
pipe = None                  
last_usage_time = 0.0        
is_timer_running = False     

async def unload_model_timer():
    """Фоновый таймер: выгружает модель через 5 минут бездействия."""
    global pipe, last_usage_time, is_timer_running
    is_timer_running = True
    
    while True:
        await asyncio.sleep(10) # Проверяем статус каждые 10 секунд
        current_time = time.time()
        
        # Если модель в памяти и прошло больше 5 минут (300 секунд)
        if pipe is not None and (current_time - last_usage_time) >= 300.0:
            print("=== [ПАМЯТЬ]: Stable Diffusion не использовалась 5 минут. Выгрузка из ОЗУ... ===")
            pipe = None
            gc.collect()
            torch.mps.empty_cache() # Полностью чистим Metal GPU кэш Mac
            print("=== [ПАМЯТЬ]: Память Mac успешно освобождена! ===")
            is_timer_running = False
            break

def load_model_if_needed():
    """Загрузка модели на ходу при первой необходимости."""
    global pipe, last_usage_time, is_timer_running
    last_usage_time = time.time()
    
    if pipe is None:
        print("=== [ПАМЯТЬ]: Требуется генерация. Загрузка Stable Diffusion на M5 Pro... ===")
        pipe = AutoPipelineForText2Image.from_pretrained(
            "stabilityai/sdxl-turbo", 
            torch_dtype=torch.float16, 
            variant="fp16"
        )
        pipe.to("mps")
        print("=== [ПАМЯТЬ]: Модель успешно загружена в память! ===")
        
        if not is_timer_running:
            asyncio.create_task(unload_model_timer())



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


def validate_actions(actions: list, context: Optional[dict]) -> list[dict]:
    """Валидация команд от ИИ, созданная автором + наша новая погода 'set_weather'."""
    safe_actions: list[dict] = []
    if not isinstance(actions, list):
        return safe_actions
    current_room = (context or {}).get("room", "")
    context_objects = {
        (item.get("room"), item.get("object")): item
        for item in (context or {}).get("objects", [])
        if isinstance(item, dict)
    }
    for raw in actions[:6]: # Увеличили лимит до 6, чтобы влезла погода
        if not isinstance(raw, dict):
            continue
        kind = raw.get("type")
        if not isinstance(kind, str):
            continue
            
        # Новая команда ИИ-Режиссера: изменение погоды (дождь, туман)
        if kind == "set_weather":
            weather_val = raw.get("value", "normal")
            if weather_val in ["normal", "rain", "fog"]:
                safe_actions.append({"type": kind, "value": weather_val})
                
        elif kind == "set_brightness":
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
    """Генерация текстового ответа на основе сработавших команд."""
    reactions: list[str] = []
    for action in actions:
        kind = action.get("type")
        if kind == "set_weather":
            w = action.get("value")
            if w == "rain": reactions.append("за окном пошел холодный дождь")
            elif w == "fog": reactions.append("комнату застилает густой туман")
        elif kind == "set_brightness":
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


from pathlib import Path

def generate_ai_image(prompt_text: str):
    """Локальная генерация хоррор-картинок на видеокарте Apple Silicon с авто-очисткой и удалением фона."""
    global pipe
    try:
        # Принудительно проверяем и загружаем Stable Diffusion, если она спит
        load_model_if_needed()
        
        full_prompt = f"{prompt_text}, isolated object asset, centered, pure black background, 2d indie horror game style, eerie dark atmosphere, cinematic lighting, spooky"
        print(f"[ИИ-КАРТИНКА]: Генерация по промпту: {full_prompt}")
        
        # 1. Генерируем сырое изображение со Stable Diffusion (оно будет на чёрном фоне)
        raw_image = pipe(prompt=full_prompt, num_inference_steps=1, guidance_scale=0.0).images[0]
        
        # 2. НЕЙРОСЕТЕВОЕ УДАЛЕНИЕ ФОНА (rembg)
        print("[ИИ-КАРТИНКА]: Вырезаю фон и делаю его прозрачным...")
        clean_image = remove(raw_image) # rembg автоматически находит границы предмета и стирает черный цвет
        
        # 3. Находим папку art проекта игры
        server_script_dir = Path(__file__).resolve().parent
        game_art_dir = server_script_dir.parent / "art"
        game_art_dir.mkdir(parents=True, exist_ok=True)
        
        final_path = game_art_dir / "dynamic_generated.png"
        
        # Стираем старый заблокированный файл перед записью
        if final_path.exists():
            try:
                final_path.unlink()
                print("[ИИ-КАРТИНКА]: Старая картинка успешно стёрта с диска.")
            except Exception as e:
                print(f"[ИИ-КАРТИНКА ПРЕДУПРЕЖДЕНИЕ]: Не удалось удалить файл напрямую: {e}")
        
        # 4. Сохраняем новую картинку с поддержкой прозрачности (в формате PNG)
        clean_image.save(str(final_path), "PNG")
        print(f"[ИИ-КАРТИНКА АВТОПУТЬ]: Чистый спрайт без фона успешно записан: {final_path}")
        
    except Exception as e:
        print(f"[ИИ-КАРТИНКА ОШИБКА]: Не удалось сгенерировать изображение или удалить фон: {e}")



# ── Эндпоинты ──
@app.post("/event", response_model=EventResponse)
async def handle_event(req: EventRequest) -> EventResponse:
    async with _state_lock:
        if req.location:
            state.location = req.location
        state.add_memory(f"{req.type}:{req.target}")

        decision = should_speak(req.type, req.target, state)
        if not decision["speak"]:
            return EventResponse(speak=False, source="silent")

        if not decision.get("use_llm", True):
            state.interventions_this_scene += 1
            state.relationship = max(-10, min(10, state.relationship + decision.get("delta", 0)))
            return EventResponse(
                speak=True,
                text=decision.get("text", ""),
                emotion=decision.get("emotion", "neutral"),
                delta_relationship=decision.get("delta", 0),
                source="cached"
            )

        # ИСПРАВЛЕНО: убрали req.context, передаем только state
        system_prompt = build_system_prompt(state)
        user_prompt = f"Произошло событие: {req.type} с объектом {req.target} в комнате {state.location}."
        
        # Требуем от Ollama вернуть команду генерации при важных событиях
        system_prompt += "\nДобавь в массив действий ('actions') объект типа {'type': 'generate_image', 'prompt': 'описание жуткой картинки на английском'}, если ситуация заслуживает визуализации."

        try:
            raw_reply = ask_ollama(system_prompt, user_prompt)
            parsed = json.loads(raw_reply)
        except Exception:
            parsed = {"text": "Что-то пошло не так...", "actions": []}

        text = parsed.get("text", "")
        raw_actions = parsed.get("actions", [])
        
        for act in raw_actions:
            if isinstance(act, dict) and act.get("type") == "generate_image":
                generate_ai_image(act.get("prompt", "scary ghost shadow"))

        safe_actions = validate_actions(raw_actions, req.context)
        text += action_reaction(safe_actions)

        return EventResponse(
            speak=True,
            text=text,
            source="llm",
            actions=safe_actions
        )


@app.post("/chat", response_model=EventResponse)
async def handle_chat(req: ChatRequest) -> EventResponse:
    async with _state_lock:
        if req.location:
            state.location = req.location

        system_prompt = build_system_prompt(state)
        
        
        # КРИТИЧЕСКИЙ ЯЗЫКОВОЙ ЯКОРЬ ДЛЯ КИТАЙСКИХ МОДЕЛЕЙ (QWEN)
        system_prompt += (
            "\n[КРИТИЧЕСКОЕ ПРАВИЛО ДЛЯ ЯЗЫКА]:\n"
            "Ты ОБЯЗАН общаться с игроком ИСКЛЮЧИТЕЛЬНО на РУССКОМ ЯЗЫКЕ. Ни в коем случае не пиши на китайском или английском языке.\n\n"
            "[ИНСТРУКЦИЯ ИИ-РЕЖИССЕРА]:\n"
            "Ты управляешь хоррор-игрой. Отвечай СТРОГО в формате JSON с ключами 'text' и 'actions'.\n"
            "Правила для массива 'actions':\n"
            "Если игрок просит предмет, добавь две команды:\n"
            "1. {'type': 'spawn_object', 'id': 'uniqu_id', 'name': 'Имя предмета на РУССКОМ'}\n"
            "2. {'type': 'generate_image', 'prompt': 'SHORT_ENGLISH_DESCRIPTION'}\n\n"
            "КРИТИЧЕСКОЕ ПРАВИЛО ДЛЯ 'prompt' ВНУТРИ ACTIONS:\n"
            "Только поле 'prompt' должно быть на АНГЛИЙСКОМ ЯЗЫКЕ и очень коротким (максимум 5-8 слов).\n"
            "Описывай только сам предмет. Никакого фона, никаких стен.\n"
            "Пример правильного ответа:\n"
            "{\n"
            '  "text": "Твоя реплика на русском языке.",\n'
            '  "actions": [\n'
            '    {"type": "spawn_object", "id": "ancient_staff", "name": "Магический посох"},\n'
            '    {"type": "generate_image", "prompt": "ancient glowing wizard staff, blue pulse"}\n'
            '  ]\n'
            "}\n"
            "Не пиши никаких рассуждений, тегов или текста до и после JSON. Выведи только структуру."
        )


        user_prompt = req.message
        
        # Объявляем переменные ЗАРАНЕЕ, чтобы избежать ошибок инициализации (UnboundLocalError)
        ai_text = "Я соткал это из темноты... Взгляни на пол."
        raw_actions = []
        image_prompt = "dark horror cryptic occult artifact item object"
        should_generate_visual = False
        is_json_valid = False
        raw_reply = ""

        try:
            raw_reply = ask_ollama(system_prompt, user_prompt)
            
            if not raw_reply or not raw_reply.strip():
                raise ValueError("Оллама вернула пустой ответ")
                
            clean_reply = raw_reply.strip()
            
            # Проверяем: если в ответе ВООБЩЕ нет фигурных скобок, значит это точно обычный текст
            if "{" not in clean_reply or "}" not in clean_reply:
                ai_text = clean_reply
                raw_actions = []
                is_json_valid = True
                print(f"[РЕЖИССЕР]: Получен чистый текстовый ответ от ИИ: {ai_text}")
            else:
                # Если скобки есть, вырезаем ТОЛЬКО первый валидный блок JSON
                # Это решает проблему "Extra data", когда ИИ пишет текст после скобки }
                start_idx = clean_reply.find("{")
                
                # Ищем закрывающую скобку, которая идет после открывающей
                end_idx = clean_reply.find("}", start_idx)
                
                if start_idx != -1 and end_idx != -1:
                    # Обрезаем строку строго от первой { до первой }
                    clean_reply = clean_reply[start_idx:end_idx + 1]
                
                parsed = json.loads(clean_reply)
                ai_text = parsed.get("text", ai_text)
                raw_actions = parsed.get("actions", [])
                is_json_valid = True
                print(f"[РЕЖИССЕР]: Успешно распарсен JSON-пакет действий. Ответ ИИ: {ai_text}")
                
        except Exception as e:
            print(f"[СВЕТИК СЕРВЕР ПРЕДУПРЕЖДЕНИЕ]: Нестандартный формат ответа: {e}. Применяем фолбек.")
            if raw_reply and len(raw_reply.strip()) > 5:
                ai_text = raw_reply.strip()

            
            # УМНЫЙ АВАРИЙНЫЙ РЕЖИМ С ПРИОРИТЕТОМ НА АНГЛИЙСКОМ
            user_lower = user_prompt.lower()
            
            # Расширили список корней для точного перехвата еды (кушать, хочу есть, конфеты)
            if any(w in user_lower for w in ["ед", "кушат", "ешь", "ест", "конфет", "перекус"]):
                image_prompt = "rotten creepy horror food ration, cursed candy bowl, dark meat on a plate"
                should_generate_visual = True
            elif any(w in user_lower for w in ["нож", "оруж", "меч", "кинж", "топор"]):
                image_prompt = "rusty sharp ritual dagger, dark entity blade"
                should_generate_visual = True
            elif any(w in user_lower for w in ["свет", "зажигал", "фонар"]):
                image_prompt = "vintage old creepy brass lighter, small flame"
                should_generate_visual = True
            else:
                image_prompt = "mysterious glowing occult horror artifact object"



        # Извлекаем промпт из валидного JSON, если он есть
        if is_json_valid:
            for act in raw_actions:
                if isinstance(act, dict) and act.get("type") == "generate_image":
                    image_prompt = act.get("prompt", image_prompt)
                    should_generate_visual = True
                    break
        else:
            # Если игрок явно просил предмет, но JSON сломался — всё равно разрешаем генерацию
            if any(w in user_prompt.lower() for w in ["дай", "нужен", "посох", "нож", "амулет", "предмет", "артефакт"]):
                should_generate_visual = True

        # ── ДИНАМИЧЕСКИЙ СТАРТ ГЕНЕРАЦИИ И ФИКС ТОКЕНОВ ДЛЯ CLIP (Лимит 77) ──
                # ── ДИНАМИЧЕСКИЙ СТАРТ ГЕНЕРАЦИИ И ФИКС ТОКЕНОВ ДЛЯ CLIP ──
        if should_generate_visual and image_prompt:
            # ПРИОРИТЕТ: Сначала идет четкое описание предмета (image_prompt), 
            # а технические стили хоррора и изоляция дописываются в самый конец!
            optimized_prompt = f"{image_prompt}, isolated object asset, centered, pure black background, 2d indie horror sprite"
            generate_ai_image(optimized_prompt)
        else:
            print("[РЕЖИССЕР]: Обычная беседа. Локальный генератор Stable Diffusion не задействуется.")

        # Обрабатываем остальные команды (свет, погода)
        safe_actions = validate_actions(raw_actions, req.context)
        
        # Синхронизируем спавн с генерацией
        has_spawn = any(act.get("type") == "spawn_object" for act in safe_actions)
        spawned_item_name = "загадочный предмет"
        
        if should_generate_visual and not has_spawn:
            safe_actions.append({
                "type": "spawn_object",
                "id": "ai_artifact",
                "name": spawned_item_name
            })
        elif has_spawn:
            # Извлекаем красивое имя предмета, которое придумал ИИ
            for act in safe_actions:
                if act.get("type") == "spawn_object":
                    spawned_item_name = act.get("name", spawned_item_name)
                    break

        # ДИНАМИЧЕСКИЙ ХОРРОР-КОНТЕКСТ:
        # Если ИИ вызвал спавн предмета, мы прикрепим это к его реплике,
        # чтобы Светик в игре звучал осознанно и понимал, что создал
        if should_generate_visual:
            if not any(w in ai_text.lower() for w in ["пол", "взгляни", "соткалось", "появился", spawned_item_name.lower()]):
                ai_text += f" Смотри... Из осколков твоих мыслей на полу материализовался {spawned_item_name}. Возьми его, если осмелишься."

        text_reply = ai_text + action_reaction(safe_actions)

        return EventResponse(
            speak=True,
            text=text_reply,
            emotion="neutral",
            delta_relationship=0,
            source="llm" if is_json_valid else "fallback",
            actions=safe_actions
        )




