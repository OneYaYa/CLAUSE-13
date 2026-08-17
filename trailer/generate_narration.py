"""Generate the Mandarin voice-over clips for the Clause 13 trailer."""

from __future__ import annotations

import asyncio
import json
from pathlib import Path

import edge_tts


ROOT = Path(__file__).resolve().parent
AUDIO_DIR = ROOT / "audio"
VOICE = "zh-CN-YunjianNeural"

# Deliberate gaps are part of the edit. Each line lands on a visual beat.
LINES = [
    {"start": 2.25, "text": "午夜之后，邀请，不再是礼貌。"},
    {"start": 7.35, "text": "它是一份，生效的契约。"},
    {"start": 12.55, "text": "你是门槛事务局的，夜间核验员。"},
    {"start": 18.25, "text": "查档案。问动机。验口供。"},
    {"start": 23.10, "text": "在有限的核验轮次里，和会说谎、会试探、也会记住承诺的，人工智能角色对话。"},
    {"start": 32.55, "text": "他们能自由回答。但真相，只服从证据。"},
    {"start": 39.75, "text": "锁定范围、代价，与离场条件。"},
    {"start": 45.35, "text": "最后，签下你的判断。"},
    {"start": 50.45, "text": "可信来客。还是，伪人？"},
    {"start": 56.35, "text": "非人，不等于伪人。"},
    {"start": 61.05, "text": "别判断它像不像人。查清，它是谁。"},
]


async def main() -> None:
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    for index, item in enumerate(LINES):
        output = AUDIO_DIR / f"vo_{index:02d}.mp3"
        communicate = edge_tts.Communicate(
            item["text"],
            VOICE,
            rate="-14%",
            volume="-3%",
            pitch="-8Hz",
        )
        await communicate.save(str(output))
        item["file"] = output.name
    (AUDIO_DIR / "narration_timing.json").write_text(
        json.dumps({"voice": VOICE, "lines": LINES}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


if __name__ == "__main__":
    asyncio.run(main())
