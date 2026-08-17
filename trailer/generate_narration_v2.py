"""Generate the restrained Mandarin voice-over for the clarity-first trailer cut."""

from __future__ import annotations

import asyncio
import json
import re
from pathlib import Path

import edge_tts


ROOT = Path(__file__).resolve().parent
AUDIO_DIR = ROOT / "audio"
SRT_PATH = ROOT / "clause13_trailer_zh-CN.srt"
TIMING_PATH = AUDIO_DIR / "narration_v2_timing.json"
VOICE = "zh-CN-YunjianNeural"

BLOCK_RE = re.compile(
    r"(?ms)^\s*(\d+)\s*\r?\n"
    r"(\d\d):(\d\d):(\d\d),(\d\d\d)\s*-->\s*"
    r"(\d\d):(\d\d):(\d\d),(\d\d\d)\s*\r?\n"
    r"(.+?)(?=\r?\n\s*\r?\n|\Z)"
)


def seconds(hours: str, minutes: str, secs: str, millis: str) -> float:
    return int(hours) * 3600 + int(minutes) * 60 + int(secs) + int(millis) / 1000


def read_srt() -> list[dict]:
    text = SRT_PATH.read_text(encoding="utf-8-sig")
    lines: list[dict] = []
    for match in BLOCK_RE.finditer(text):
        subtitle = " ".join(part.strip() for part in match.group(10).splitlines() if part.strip())
        lines.append(
            {
                "start": seconds(*match.groups()[1:5]),
                "end": seconds(*match.groups()[5:9]),
                "text": subtitle,
            }
        )
    if not lines:
        raise ValueError(f"No subtitle entries found in {SRT_PATH}")
    return lines


def narration_text(subtitle: str) -> str:
    # Preserve the user's copy in the SRT while giving the voice engine a clean reading.
    spoken = subtitle.replace("ai npc", "AI NPC").replace("AI NPC对话", "AI NPC 对话")
    return spoken


async def main() -> None:
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    lines = read_srt()
    for index, item in enumerate(lines):
        output = AUDIO_DIR / f"v2_vo_{index:02d}.mp3"
        communicate = edge_tts.Communicate(
            narration_text(item["text"]),
            VOICE,
            rate="-9%",
            volume="-3%",
            pitch="-8Hz",
        )
        await communicate.save(str(output))
        item["file"] = output.name
    TIMING_PATH.write_text(
        json.dumps({"voice": VOICE, "source": SRT_PATH.name, "lines": lines}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


if __name__ == "__main__":
    asyncio.run(main())
