"""Tiny optional AI dialogue sidecar for Clause 13.

The Godot client owns all state changes and ending logic. This service only
rewrites an already-authoritative semantic read into an in-character reply.
It uses the OpenAI Responses API with a strict JSON schema and requires only
Python's standard library.
"""

from __future__ import annotations

import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parent
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8793
DEFAULT_MODEL = "gpt-5.6-luna"
OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses"


def load_dotenv(path: Path) -> None:
    if not path.exists():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


def build_system_prompt(context: dict[str, Any]) -> str:
    npc = context.get("npc", {})
    state = context.get("state", {})
    read = context.get("authoritative_read", {})
    facts = context.get("known_facts", [])
    dossier = context.get("public_dossier", {})
    transcript = context.get("transcript", [])
    return f"""你正在扮演中文超自然谈判游戏《第十三条款》中的来客。

角色：{npc.get('name', '来客')} / {npc.get('kind', '异类')}
对外身份：{npc.get('claim', '')}
人格：{npc.get('persona', '')}
语气参考：{json.dumps(npc.get('voice_examples', {}), ensure_ascii=False)}

当前关系：信任 {state.get('trust', 0)}，压迫 {state.get('pressure', 0)}，情绪 {state.get('mood', 'watchful')}。
角色记忆：{json.dumps(state.get('memory', {}), ensure_ascii=False)}
最近对话：{json.dumps(transcript, ensure_ascii=False)}
玩家手中的公开档案：{json.dumps(dossier, ensure_ascii=False)}

本地规则引擎已确定本轮语义，不得更改：
- intent={read.get('intent', 'conversation')}
- topic={read.get('topic', 'general')}
- 本轮必须透露的事实原句={read.get('required_fact', '') or '无'}
- 已知事实={json.dumps(facts, ensure_ascii=False)}

只输出角色本人说的一段中文对白，60—180 字。保持自然、具体、有潜台词；可以撒娇、讽刺、谈条件或回忆玩家的承诺。不得提及模型、JSON、数值、规则引擎、正确答案或隐藏评分。不得宣布契约已经签署、改变世界状态、添加新人物/物品/事实。本轮若有“必须透露的事实原句”，必须保留其事实含义，但可按角色口吻改写。"""


def build_openai_payload(context: dict[str, Any], message: str, model: str) -> dict[str, Any]:
    return {
        "model": model,
        "input": [
            {"role": "system", "content": build_system_prompt(context)},
            {"role": "user", "content": message},
        ],
        "max_output_tokens": 260,
        "text": {
            "format": {
                "type": "json_schema",
                "name": "clause13_npc_reply",
                "strict": True,
                "schema": {
                    "type": "object",
                    "properties": {"reply": {"type": "string"}},
                    "required": ["reply"],
                    "additionalProperties": False,
                },
            }
        },
    }


def extract_output_text(response: dict[str, Any]) -> str:
    for item in response.get("output", []):
        if not isinstance(item, dict) or item.get("type") != "message":
            continue
        for content in item.get("content", []):
            if isinstance(content, dict) and content.get("type") == "output_text":
                return str(content.get("text", ""))
    return ""


def request_model(context: dict[str, Any], message: str) -> dict[str, str]:
    api_key = os.getenv("OPENAI_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY is not configured")
    model = os.getenv("CLAUSE13_MODEL", DEFAULT_MODEL).strip() or DEFAULT_MODEL
    payload = build_openai_payload(context, message, model)
    request = Request(
        OPENAI_RESPONSES_URL,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urlopen(request, timeout=30) as response:
            parsed = json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")[:500]
        raise RuntimeError(f"OpenAI HTTP {exc.code}: {detail}") from exc
    except URLError as exc:
        raise RuntimeError(f"OpenAI network error: {exc.reason}") from exc
    output_text = extract_output_text(parsed)
    if not output_text:
        raise RuntimeError("OpenAI response contained no output_text")
    structured = json.loads(output_text)
    reply = str(structured.get("reply", "")).strip()
    if not reply:
        raise RuntimeError("OpenAI structured output contained an empty reply")
    return {"reply": reply[:600], "model": model}


class Handler(BaseHTTPRequestHandler):
    server_version = "Clause13Dialogue/0.1"

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(204)
        self._cors_headers()
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        if self.path.rstrip("/") != "/health":
            self._json(404, {"error": "not_found"})
            return
        self._json(
            200,
            {
                "ok": True,
                "configured": bool(os.getenv("OPENAI_API_KEY", "").strip()),
                "model": os.getenv("CLAUSE13_MODEL", DEFAULT_MODEL),
                "authority": "dialogue_only",
            },
        )

    def do_POST(self) -> None:  # noqa: N802
        if self.path.rstrip("/") != "/api/dialogue":
            self._json(404, {"error": "not_found"})
            return
        try:
            content_length = min(int(self.headers.get("Content-Length", "0")), 200_000)
            payload = json.loads(self.rfile.read(content_length).decode("utf-8"))
            message = str(payload.get("message", "")).strip()[:500]
            context = payload.get("context", {})
            if not message or not isinstance(context, dict):
                self._json(400, {"error": "message_and_context_required"})
                return
            result = request_model(context, message)
            self._json(200, {"reply": result["reply"], "provider": "openai", "model": result["model"]})
        except (ValueError, json.JSONDecodeError) as exc:
            self._json(400, {"error": "invalid_json", "detail": str(exc)[:200]})
        except Exception as exc:  # Sidecar must fail closed; Godot falls back locally.
            self._json(503, {"error": "dialogue_unavailable", "detail": str(exc)[:500]})

    def log_message(self, fmt: str, *args: Any) -> None:
        sys.stdout.write("[clause13] " + fmt % args + "\n")

    def _cors_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")

    def _json(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self._cors_headers()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    load_dotenv(ROOT / ".env")
    host = os.getenv("CLAUSE13_HOST", DEFAULT_HOST)
    port = int(os.getenv("CLAUSE13_PORT", str(DEFAULT_PORT)))
    server = ThreadingHTTPServer((host, port), Handler)
    configured = "configured" if os.getenv("OPENAI_API_KEY", "").strip() else "NO API KEY"
    print(f"Clause 13 dialogue service: http://{host}:{port} ({configured})")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
