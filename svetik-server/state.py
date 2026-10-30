from dataclasses import dataclass, field
from typing import List, Dict
import json
from pathlib import Path


@dataclass
class SvetikState:
    relationship: int = 0

    memory: List[str] = field(default_factory=list)

    interventions_this_scene: int = 0

    inventory: List[str] = field(default_factory=list)

    active_quests: List[str] = field(default_factory=list)

    location: str = "дом"

    forbidden_keywords: List[str] = field(default_factory=lambda: [
        "языковая модель", "нейросеть", "искусственный интеллект",
        "chatgpt", "openai", "llm", "gpt", "реальный мир",
        "godot", "python", "разработчик",
    ])

    def add_memory(self, event: str, keep: int = 10) -> None:
        """Добавить событие в память, оставив только N последних."""
        self.memory.append(event)
        self.memory = self.memory[-keep:]

    def to_dict(self) -> dict:
        return {
            "relationship": self.relationship,
            "memory": self.memory,
            "interventions_this_scene": self.interventions_this_scene,
            "inventory": self.inventory,
            "active_quests": self.active_quests,
            "location": self.location,
        }

    def save(self, path: str = "state.json") -> None:
        """Сохранить состояние на диск."""
        Path(path).write_text(
            json.dumps(self.to_dict(), ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    def load(self, path: str = "state.json") -> None:
        """Загрузить состояние с диска (если есть)."""
        p = Path(path)
        if not p.exists():
            return
        data = json.loads(p.read_text(encoding="utf-8"))
        self.relationship = data.get("relationship", 0)
        self.memory = data.get("memory", [])
        self.inventory = data.get("inventory", [])
        self.active_quests = data.get("active_quests", [])
        self.location = data.get("location", "дом")