import os
import shutil
import subprocess
import time
from pathlib import Path
import requests
from typing import Any, Optional


OLLAMA_URL = "http://127.0.0.1:11434"
# This model is installed locally. If Ollama is stopped, start it on demand.
MODEL = "qwen2.5:7b"


class LLMError(Exception):
    pass


def _ensure_ollama_running(timeout: int) -> None:
    try:
        requests.get(f"{OLLAMA_URL}/api/tags", timeout=1).raise_for_status()
        return
    except requests.exceptions.RequestException:
        pass

    executable = shutil.which("ollama")
    if not executable and os.name == "nt":
        local_app_data = os.environ.get("LOCALAPPDATA", "")
        if local_app_data:
            candidate = Path(local_app_data) / "Programs" / "Ollama" / "ollama.exe"
            if candidate.is_file():
                executable = str(candidate)
    if not executable:
        raise LLMError("Ollama не запущена и не найдена на этом компьютере")

    try:
        subprocess.Popen(
            [executable, "serve"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
    except OSError as error:
        raise LLMError(f"Не удалось запустить Ollama: {error}") from error

    deadline = time.monotonic() + min(max(timeout, 5), 20)
    while time.monotonic() < deadline:
        try:
            requests.get(f"{OLLAMA_URL}/api/tags", timeout=1).raise_for_status()
            return
        except requests.exceptions.RequestException:
            time.sleep(0.25)
    raise LLMError("Ollama не запустилась вовремя")


def ask_ollama(system_prompt: str, user_message: str,
               temperature: float = 0.8,
               max_tokens: int = 120,
               timeout: int = 30,
               response_format: Optional[Any] = None) -> str:
    """
    Отправить запрос в Ollama и вернуть текст ответа.
    Бросает LLMError при проблемах.
    """
    payload = {
        "model": MODEL,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message},
        ],
        "stream": False,
        "think": False,
        "options": {
            "temperature": temperature,
            "num_predict": max_tokens,
            "top_p": 0.9,
        },
    }
    if response_format is not None:
        payload["format"] = response_format

    try:
        resp = requests.post(
            f"{OLLAMA_URL}/api/chat",
            json=payload,
            timeout=timeout,
        )
        resp.raise_for_status()
    except requests.exceptions.ConnectionError:
        _ensure_ollama_running(timeout)
        try:
            resp = requests.post(
                f"{OLLAMA_URL}/api/chat",
                json=payload,
                timeout=timeout,
            )
            resp.raise_for_status()
        except requests.exceptions.ConnectionError as error:
            raise LLMError(f"Ollama недоступна: {error}") from error
        except requests.exceptions.Timeout as error:
            raise LLMError(f"Ollama не ответила за {timeout}с") from error
        except requests.exceptions.HTTPError as error:
            raise LLMError(f"Ollama вернула ошибку: {error}") from error
    except requests.exceptions.Timeout:
        raise LLMError(f"Ollama не ответил за {timeout}с")
    except requests.exceptions.HTTPError as e:
        raise LLMError(f"Ollama вернул ошибку: {e}")

    data = resp.json()
    text = data.get("message", {}).get("content", "").strip()

    if not text:
        raise LLMError("Ollama вернул пустой ответ")

    return text
