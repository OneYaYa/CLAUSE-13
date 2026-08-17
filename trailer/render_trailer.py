"""Render the 72-second Clause 13 gameplay trailer from project-owned assets."""

from __future__ import annotations

import json
import math
import subprocess
import wave
from pathlib import Path

import imageio_ffmpeg
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parent
CAPTURES = ROOT / "captures"
AUDIO = ROOT / "audio"
OUTPUT = ROOT / "output"
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()

W, H = 1920, 1080
FPS = 24
DURATION = 72.0
TOTAL_FRAMES = int(DURATION * FPS)

FONT_SERIF = Path(r"C:\Windows\Fonts\NotoSerifSC-VF.ttf")
FONT_SANS = Path(r"C:\Windows\Fonts\NotoSansSC-VF.ttf")
FONT_SANS_BOLD = Path(r"C:\Windows\Fonts\msyhbd.ttc")

CREAM = (229, 221, 204)
AMBER = (211, 173, 82)
JADE = (108, 174, 139)
RED = (181, 69, 61)
MUTED = (151, 156, 148)
BLACK = (4, 6, 6)

RESAMPLE = Image.Resampling.LANCZOS


def ease(value: float) -> float:
    value = min(1.0, max(0.0, value))
    return value * value * (3.0 - 2.0 * value)


def load_sources() -> dict[str, Image.Image]:
    paths = {
        "rain_art": PROJECT / "assets/encounters/rain_guest_v1.png",
        "tailor_art": PROJECT / "assets/encounters/shadow_tailor_v1.png",
        "red_art": PROJECT / "assets/encounters/red_rescue_v1.png",
        "inspector_art": PROJECT / "assets/encounters/training_inspector_v1.png",
        "training_ui": CAPTURES / "training_dialogue.png",
        "rain_ui": CAPTURES / "rain_dialogue.png",
        "rain_evidence": CAPTURES / "rain_evidence.png",
        "shadow_contract": CAPTURES / "shadow_contract.png",
        "red_ui": CAPTURES / "red_dialogue.png",
        "red_contract": CAPTURES / "red_contract.png",
    }
    sources: dict[str, Image.Image] = {}
    for name, path in paths.items():
        image = Image.open(path).convert("RGB")
        if name.endswith("_art"):
            image = ImageEnhance.Color(image).enhance(0.82)
            image = ImageEnhance.Contrast(image).enhance(1.12)
            image = ImageEnhance.Brightness(image).enhance(0.86)
        else:
            image = ImageEnhance.Contrast(image).enhance(1.04)
            image = ImageEnhance.Brightness(image).enhance(0.93)
        sources[name] = image
    return sources


def cover(
    source: Image.Image,
    zoom: float = 1.0,
    pan_x: float = 0.0,
    pan_y: float = 0.0,
    target: tuple[int, int] = (W, H),
) -> Image.Image:
    target_w, target_h = target
    sw, sh = source.size
    scale = max(target_w / sw, target_h / sh) * zoom
    rw, rh = max(target_w, round(sw * scale)), max(target_h, round(sh * scale))
    resized = source.resize((rw, rh), RESAMPLE)
    excess_x = max(0, rw - target_w)
    excess_y = max(0, rh - target_h)
    left = int(excess_x * (0.5 + 0.5 * min(1.0, max(-1.0, pan_x))))
    top = int(excess_y * (0.5 + 0.5 * min(1.0, max(-1.0, pan_y))))
    return resized.crop((left, top, left + target_w, top + target_h))


def add_dark_overlay(image: Image.Image, opacity: int) -> Image.Image:
    return Image.blend(image, Image.new("RGB", image.size, BLACK), opacity / 255.0)


def text_layer() -> Image.Image:
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size=size)


FONTS = {
    "hero": font(FONT_SERIF, 88),
    "hero_small": font(FONT_SERIF, 70),
    "title_cn": font(FONT_SERIF, 118),
    "title_en": font(FONT_SANS_BOLD, 27),
    "section": font(FONT_SANS_BOLD, 35),
    "body": font(FONT_SANS, 30),
    "small": font(FONT_SANS, 21),
    "micro": font(FONT_SANS, 17),
    "subtitle": font(FONT_SANS, 31),
}


def draw_caption(
    image: Image.Image,
    title: str,
    eyebrow: str = "",
    x: int = 132,
    y: int = 145,
    color: tuple[int, int, int] = CREAM,
    align: str = "left",
) -> Image.Image:
    layer = text_layer()
    draw = ImageDraw.Draw(layer)
    anchor = "la" if align == "left" else "ma"
    if eyebrow:
        draw.text((x, y - 48), eyebrow, font=FONTS["small"], fill=AMBER + (230,), anchor=anchor)
        if align == "left":
            draw.line((x, y - 13, x + 210, y - 13), fill=AMBER + (145,), width=2)
    draw.text(
        (x, y),
        title,
        font=FONTS["hero"],
        fill=color + (245,),
        anchor=anchor,
        stroke_width=2,
        stroke_fill=(0, 0, 0, 180),
    )
    return Image.alpha_composite(image.convert("RGBA"), layer).convert("RGB")


def draw_hud_label(image: Image.Image, title: str, detail: str, x: int, y: int, accent=AMBER) -> Image.Image:
    layer = text_layer()
    draw = ImageDraw.Draw(layer)
    title_box = draw.textbbox((0, 0), title, font=FONTS["section"])
    width = max(360, title_box[2] - title_box[0] + 64)
    draw.rounded_rectangle((x, y, x + width, y + 100), radius=4, fill=(5, 10, 11, 220), outline=accent + (180,), width=2)
    draw.text((x + 24, y + 18), title, font=FONTS["section"], fill=CREAM + (245,))
    draw.text((x + 25, y + 66), detail, font=FONTS["micro"], fill=accent + (225,))
    return Image.alpha_composite(image.convert("RGBA"), layer).convert("RGB")


def title_background(sources: dict[str, Image.Image]) -> Image.Image:
    canvas = Image.new("RGB", (W, H), BLACK)
    names = ["rain_art", "tailor_art", "red_art"]
    panel_w = W // 3
    for index, name in enumerate(names):
        panel = cover(sources[name], 1.42, 0.0, -0.08, (panel_w, H))
        panel = ImageEnhance.Brightness(panel).enhance(0.42)
        canvas.paste(panel, (index * panel_w, 0))
    canvas = add_dark_overlay(canvas, 138)
    return canvas


def render_scene(t: float, sources: dict[str, Image.Image], title_bg: Image.Image) -> Image.Image:
    if t < 2.0:
        frame = Image.new("RGB", (W, H), BLACK)
        layer = text_layer()
        draw = ImageDraw.Draw(layer)
        alpha = int(120 * ease(t / 1.4))
        draw.text((W // 2, H // 2 - 8), "THRESHOLD RECORD // 02:13", font=FONTS["micro"], fill=AMBER + (alpha,), anchor="mm")
        frame = Image.alpha_composite(frame.convert("RGBA"), layer).convert("RGB")
    elif t < 7.2:
        p = (t - 2.0) / 5.2
        frame = cover(sources["rain_art"], 1.045 + 0.035 * p, 0.02, -0.08 + 0.08 * p)
        frame = add_dark_overlay(frame, 62)
        frame = draw_caption(frame, "午夜之后", "门槛事件 / THRESHOLD EVENT", 132, 162)
    elif t < 12.4:
        p = (t - 7.2) / 5.2
        frame = cover(sources["rain_art"], 1.38 + 0.06 * p, 0.0, -0.12)
        frame = add_dark_overlay(frame, 94)
        frame = draw_caption(frame, "邀请即契约", "CLAUSE 13 // INVITATION PROTOCOL", W // 2, 224, AMBER, "center")
    elif t < 14.7:
        p = ease((t - 12.4) / 2.3)
        frame = Image.blend(cover(sources["rain_art"], 1.72, 0.84, 0.08), Image.new("RGB", (W, H), BLACK), 0.72 + 0.2 * p)
        layer = text_layer()
        draw = ImageDraw.Draw(layer)
        draw.line((420, 390, 1500, 390), fill=AMBER + (155,), width=2)
        draw.text((W // 2, 468), "一份自愿签署、即时生效的许可", font=FONTS["hero_small"], fill=CREAM + (245,), anchor="mm")
        draw.text((W // 2, 555), "THE CITY REMEMBERS EVERY PROMISE", font=FONTS["small"], fill=MUTED + (220,), anchor="mm")
        draw.line((420, 635, 1500, 635), fill=AMBER + (155,), width=2)
        frame = Image.alpha_composite(frame.convert("RGBA"), layer).convert("RGB")
    elif t < 18.2:
        p = (t - 14.7) / 3.5
        frame = cover(sources["training_ui"], 1.015 + 0.025 * p, 0.0, 0.0)
        frame = draw_hud_label(frame, "夜间核验员", "门槛事务局 // NIGHT SHIFT", 116, 126, JADE)
    elif t < 19.8:
        p = (t - 18.2) / 1.6
        frame = cover(sources["rain_evidence"], 1.72 + 0.04 * p, -0.93, -0.02)
        frame = draw_hud_label(frame, "查档案", "只读记录 // DOSSIER", 1160, 155)
    elif t < 21.4:
        p = (t - 19.8) / 1.6
        frame = cover(sources["rain_ui"], 1.64 + 0.04 * p, 0.02, 0.96)
        frame = draw_hud_label(frame, "问动机", "自由输入 // FREE INTERROGATION", 116, 145)
    elif t < 23.1:
        p = (t - 21.4) / 1.7
        frame = cover(sources["rain_evidence"], 1.75 + 0.04 * p, -0.90, -0.05)
        frame = draw_hud_label(frame, "验口供", "证据解锁 // CROSS-CHECK", 1150, 150, RED)
    elif t < 26.3:
        p = (t - 23.1) / 3.2
        frame = cover(sources["rain_ui"], 1.02 + 0.025 * p, 0.0, 0.0)
        frame = add_dark_overlay(frame, 28)
        frame = draw_caption(frame, "每一句回答，都留下痕迹", "AI NPC // CONVERSATION MEMORY", 125, 142)
    elif t < 29.4:
        p = (t - 26.3) / 3.1
        frame = cover(sources["rain_art"], 1.1 + 0.055 * p, -0.02, -0.08)
        frame = add_dark_overlay(frame, 70)
        frame = draw_hud_label(frame, "会试探", "信任 / 压迫 / 记忆", 118, 730, JADE)
    elif t < 32.5:
        p = (t - 29.4) / 3.1
        frame = cover(sources["tailor_art"], 1.08 + 0.065 * p, 0.0, -0.06)
        frame = add_dark_overlay(frame, 72)
        frame = draw_hud_label(frame, "会隐瞒", "私有动机 / 受约束揭示", 116, 730, RED)
    elif t < 35.6:
        p = (t - 32.5) / 3.1
        frame = cover(sources["red_art"], 1.08 + 0.065 * p, 0.0, -0.05)
        frame = add_dark_overlay(frame, 70)
        frame = draw_hud_label(frame, "会记住", "你的承诺，会成为下一句台词", 112, 730, AMBER)
    elif t < 39.6:
        p = (t - 35.6) / 4.0
        frame = cover(sources["red_ui"], 1.03 + 0.035 * p, 0.0, 0.18)
        layer = text_layer()
        draw = ImageDraw.Draw(layer)
        draw.rounded_rectangle((107, 120, 820, 327), radius=5, fill=(4, 8, 9, 224), outline=AMBER + (150,), width=2)
        draw.text((145, 154), "AI NPC", font=FONTS["hero_small"], fill=AMBER + (250,))
        draw.text((149, 247), "自由回应  /  关系记忆  /  受约束隐瞒", font=FONTS["body"], fill=CREAM + (235,))
        draw.text((149, 292), "NPC 决定怎么说 · 世界状态机决定什么是真的", font=FONTS["small"], fill=JADE + (225,))
        frame = Image.alpha_composite(frame.convert("RGBA"), layer).convert("RGB")
    elif t < 44.8:
        p = (t - 39.6) / 5.2
        frame = cover(sources["shadow_contract"], 1.56 + 0.035 * p, 0.94, -0.02)
        frame = add_dark_overlay(frame, 15)
        layer = text_layer()
        draw = ImageDraw.Draw(layer)
        labels = [("01", "范围"), ("02", "代价"), ("03", "离场")]
        for index, (number, label) in enumerate(labels):
            alpha = int(245 * ease((p * 4.0 - index * 0.72)))
            y = 224 + index * 164
            draw.text((154, y), number, font=FONTS["small"], fill=AMBER + (alpha,))
            draw.text((220, y - 9), label, font=FONTS["hero_small"], fill=CREAM + (alpha,))
            draw.line((154, y + 78, 650, y + 78), fill=AMBER + (int(alpha * 0.55),), width=2)
        frame = Image.alpha_composite(frame.convert("RGBA"), layer).convert("RGB")
    elif t < 49.7:
        p = (t - 44.8) / 4.9
        frame = cover(sources["red_contract"], 1.06 + 0.03 * p, 0.08, 0.0)
        layer = text_layer()
        draw = ImageDraw.Draw(layer)
        box_alpha = int(210 * ease(p * 2.0))
        draw.rounded_rectangle((116, 136, 715, 286), radius=5, fill=(4, 7, 8, box_alpha), outline=JADE + (160,), width=2)
        draw.text((150, 170), "3 / 3  条款一致", font=FONTS["hero_small"], fill=JADE + (240,))
        draw.text((153, 250), "协议提供线索 · 判断仍由你承担", font=FONTS["small"], fill=CREAM + (225,))
        frame = Image.alpha_composite(frame.convert("RGBA"), layer).convert("RGB")
    elif t < 53.7:
        p = (t - 49.7) / 4.0
        frame = cover(sources["red_contract"], 1.78 + 0.06 * p, 0.96, 0.92)
        frame = add_dark_overlay(frame, 42)
        layer = text_layer()
        draw = ImageDraw.Draw(layer)
        draw.text((W // 2, 175), "最终判断", font=FONTS["hero"], fill=CREAM + (245,), anchor="mm")
        draw.text((W // 2, 262), "VERDICT", font=FONTS["title_en"], fill=AMBER + (235,), anchor="mm")
        frame = Image.alpha_composite(frame.convert("RGBA"), layer).convert("RGB")
    elif t < 56.0:
        index = min(2, int((t - 53.7) / 0.77))
        names = ["rain_art", "tailor_art", "red_art"]
        frame = cover(sources[names[index]], 1.32, 0.0, -0.08)
        frame = add_dark_overlay(frame, 58)
        layer = text_layer()
        draw = ImageDraw.Draw(layer)
        if index < 2:
            draw.text((W // 2, H // 2), "伪人？", font=FONTS["hero"], fill=RED + (245,), anchor="mm")
        else:
            draw.text((W // 2, H // 2), "可信来客？", font=FONTS["hero"], fill=JADE + (245,), anchor="mm")
        frame = Image.alpha_composite(frame.convert("RGBA"), layer).convert("RGB")
    elif t < 60.6:
        p = (t - 56.0) / 4.6
        frame = cover(sources["red_art"], 1.16 + 0.06 * p, 0.0, -0.08)
        frame = add_dark_overlay(frame, 112)
        layer = text_layer()
        draw = ImageDraw.Draw(layer)
        draw.text((W // 2, 420), "非人", font=FONTS["hero"], fill=CREAM + (248,), anchor="mm")
        draw.text((W // 2, 530), "≠", font=FONTS["hero_small"], fill=AMBER + (250,), anchor="mm")
        draw.text((W // 2, 645), "伪人", font=FONTS["hero"], fill=CREAM + (248,), anchor="mm")
        frame = Image.alpha_composite(frame.convert("RGBA"), layer).convert("RGB")
    elif t < 65.0:
        p = (t - 60.6) / 4.4
        frame = cover(sources["rain_art"], 1.6 + 0.06 * p, 0.0, -0.12)
        frame = add_dark_overlay(frame, 196)
        layer = text_layer()
        draw = ImageDraw.Draw(layer)
        draw.text((W // 2, 410), "别判断它像不像人", font=FONTS["hero_small"], fill=CREAM + (245,), anchor="mm")
        reveal = ease((p - 0.42) / 0.45)
        draw.text((W // 2, 545), "查清，它是谁", font=FONTS["hero"], fill=AMBER + (int(250 * reveal),), anchor="mm")
        frame = Image.alpha_composite(frame.convert("RGBA"), layer).convert("RGB")
    else:
        p = (t - 65.0) / 7.0
        frame = title_bg.copy()
        frame = ImageEnhance.Brightness(frame).enhance(0.88 + 0.08 * math.sin(p * math.pi))
        layer = text_layer()
        draw = ImageDraw.Draw(layer)
        alpha = int(250 * ease(p / 0.20))
        draw.text((W // 2, 378), "第十三条款", font=FONTS["title_cn"], fill=CREAM + (alpha,), anchor="mm", stroke_width=2, stroke_fill=(0, 0, 0, alpha))
        draw.line((570, 475, 1350, 475), fill=AMBER + (int(alpha * 0.8),), width=2)
        draw.text((W // 2, 532), "CLAUSE 13 : NIGHT NOTARY", font=FONTS["title_en"], fill=AMBER + (alpha,), anchor="mm")
        draw.text((W // 2, 620), "AI 原生谈判解谜  ×  都市怪谈", font=FONTS["body"], fill=CREAM + (int(alpha * 0.88),), anchor="mm")
        draw.text((W // 2, 742), "门外的身份，由你签字确认", font=FONTS["small"], fill=MUTED + (int(alpha * 0.9),), anchor="mm")
        frame = Image.alpha_composite(frame.convert("RGBA"), layer).convert("RGB")
    return frame


def make_vignette() -> Image.Image:
    yy, xx = np.mgrid[0:H, 0:W]
    nx = (xx - W / 2) / (W / 2)
    ny = (yy - H / 2) / (H / 2)
    radius = np.sqrt(nx * nx + ny * ny)
    alpha = np.clip((radius - 0.42) / 0.68, 0, 1) ** 1.7
    alpha = (alpha * 125).astype(np.uint8)
    rgba = np.zeros((H, W, 4), dtype=np.uint8)
    rgba[..., 3] = alpha
    return Image.fromarray(rgba, "RGBA")


def make_scanlines() -> Image.Image:
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for y in range(0, H, 4):
        draw.line((0, y, W, y), fill=(0, 0, 0, 11), width=1)
    return layer


def make_grain_frames() -> list[Image.Image]:
    rng = np.random.default_rng(1313)
    frames = []
    for _ in range(10):
        noise = rng.normal(128, 30, (135, 240)).clip(0, 255).astype(np.uint8)
        small = Image.fromarray(noise, "L")
        large = small.resize((W, H), Image.Resampling.BILINEAR)
        grain = Image.merge("RGBA", (large, large, large, Image.new("L", (W, H), 15)))
        frames.append(grain)
    return frames


def glitch_strength(t: float) -> float:
    beats = [(7.18, 0.12), (12.37, 0.10), (26.25, 0.12), (29.36, 0.12), (32.48, 0.12), (39.58, 0.15), (49.68, 0.16), (53.68, 0.13), (60.56, 0.18), (64.96, 0.16)]
    result = 0.0
    for beat, width in beats:
        distance = abs(t - beat)
        if distance < width:
            result = max(result, 1.0 - distance / width)
    return result


def apply_glitch(image: Image.Image, strength: float, frame_index: int) -> Image.Image:
    if strength <= 0.01:
        return image
    rng = np.random.default_rng(1313 + frame_index)
    arr = np.asarray(image).copy()
    shift = max(1, int(8 * strength))
    arr[..., 0] = np.roll(arr[..., 0], shift, axis=1)
    arr[..., 2] = np.roll(arr[..., 2], -shift, axis=1)
    for _ in range(3):
        y = int(rng.integers(70, H - 90))
        height = int(rng.integers(8, 34))
        offset = int(rng.integers(-45, 46) * strength)
        arr[y : y + height] = np.roll(arr[y : y + height], offset, axis=1)
    return Image.fromarray(arr, "RGB")


def subtitle_for_time(t: float, lines: list[dict]) -> str:
    for index, item in enumerate(lines):
        next_start = lines[index + 1]["start"] if index + 1 < len(lines) else 65.0
        duration = max(2.4, len(item["text"]) * 0.255)
        end = min(next_start - 0.25, item["start"] + duration)
        if item["start"] <= t <= end:
            return item["text"]
    return ""


def add_subtitle(image: Image.Image, text: str) -> Image.Image:
    if not text:
        return image
    layer = text_layer()
    draw = ImageDraw.Draw(layer)
    bbox = draw.textbbox((0, 0), text, font=FONTS["subtitle"], stroke_width=1)
    tw = bbox[2] - bbox[0]
    x, y = W // 2, H - 75
    draw.rounded_rectangle((x - tw // 2 - 25, y - 29, x + tw // 2 + 25, y + 30), radius=3, fill=(3, 5, 5, 182))
    draw.text((x, y), text, font=FONTS["subtitle"], fill=CREAM + (242,), anchor="mm", stroke_width=1, stroke_fill=(0, 0, 0, 210))
    return Image.alpha_composite(image.convert("RGBA"), layer).convert("RGB")


def apply_finish(image: Image.Image, frame_index: int, vignette: Image.Image, scanlines: Image.Image, grains: list[Image.Image]) -> Image.Image:
    image = apply_glitch(image, glitch_strength(frame_index / FPS), frame_index)
    rgba = image.convert("RGBA")
    rgba = Image.alpha_composite(rgba, vignette)
    rgba = Image.alpha_composite(rgba, scanlines)
    rgba = Image.alpha_composite(rgba, grains[frame_index % len(grains)])
    draw = ImageDraw.Draw(rgba)
    draw.rectangle((0, 0, W, 34), fill=(0, 0, 0, 235))
    draw.rectangle((0, H - 34, W, H), fill=(0, 0, 0, 235))
    return rgba.convert("RGB")


def add_event(track: np.ndarray, sample_rate: int, start: float, signal: np.ndarray) -> None:
    begin = int(start * sample_rate)
    if begin >= len(track):
        return
    end = min(len(track), begin + len(signal))
    track[begin:end] += signal[: end - begin]


def generate_soundtrack(path: Path) -> None:
    sr = 48_000
    n = int(DURATION * sr)
    t = np.arange(n, dtype=np.float64) / sr
    rng = np.random.default_rng(1313)

    # Slowly moving electrical/architectural drone.
    envelope = 0.62 + 0.22 * np.sin(2 * np.pi * 0.031 * t)
    track = envelope * (
        0.055 * np.sin(2 * np.pi * 38.0 * t)
        + 0.032 * np.sin(2 * np.pi * 57.0 * t + 0.8 * np.sin(2 * np.pi * 0.07 * t))
        + 0.018 * np.sin(2 * np.pi * 83.0 * t)
    )

    white = rng.normal(0, 1, n)
    window = 160
    low = np.convolve(white, np.ones(window) / window, mode="same")
    track += 0.020 * low
    rain_gate = np.zeros(n)
    rain_gate[int(1.8 * sr) : int(12.5 * sr)] = 1.0
    rain_gate[int(53.5 * sr) : int(61.0 * sr)] = 0.55
    track += 0.010 * white * rain_gate

    # Two heavy knocks: wood body, short click, and room tail.
    for knock_time, gain in [(0.72, 0.52), (1.38, 0.42)]:
        x = np.arange(int(0.85 * sr)) / sr
        knock = gain * np.exp(-x * 11.0) * (
            np.sin(2 * np.pi * (68 - 18 * x) * x) + 0.34 * np.sin(2 * np.pi * 132 * x)
        )
        knock += gain * 0.09 * rng.normal(0, 1, len(x)) * np.exp(-x * 35.0)
        add_event(track, sr, knock_time, knock)

    cut_beats = [7.2, 12.4, 14.7, 18.2, 23.1, 26.3, 29.4, 32.5, 35.6, 39.6, 44.8, 49.7, 53.7, 56.0, 60.6, 65.0]
    for index, beat in enumerate(cut_beats):
        x = np.arange(int(0.65 * sr)) / sr
        freq = 46.0 + (index % 3) * 7.0
        impact = 0.19 * np.exp(-x * 7.0) * np.sin(2 * np.pi * (freq - 17 * x) * x)
        impact += 0.025 * rng.normal(0, 1, len(x)) * np.exp(-x * 18.0)
        add_event(track, sr, beat, impact)

    # Protocol locks: dry metallic confirmations.
    for ping_time, freq in [(40.6, 880), (42.05, 1040), (43.55, 1240)]:
        x = np.arange(int(0.55 * sr)) / sr
        ping = 0.055 * np.exp(-x * 8.5) * (np.sin(2 * np.pi * freq * x) + 0.42 * np.sin(2 * np.pi * freq * 1.51 * x))
        add_event(track, sr, ping_time, ping)

    # Heartbeat enters for the verdict, then falls away before the title.
    for beat in np.arange(49.7, 59.8, 0.91):
        x = np.arange(int(0.42 * sr)) / sr
        heart = 0.11 * np.exp(-x * 18.0) * np.sin(2 * np.pi * 54 * x)
        heart += 0.06 * np.exp(-np.maximum(0.0, x - 0.13) * 21.0) * np.sin(2 * np.pi * 46 * np.maximum(0.0, x - 0.13)) * (x >= 0.13)
        add_event(track, sr, float(beat), heart)

    # Restrained final chord, no blockbuster blast.
    x = np.arange(int(7.0 * sr)) / sr
    final = np.zeros_like(x)
    for freq, amp in [(41.2, 0.10), (61.8, 0.055), (92.7, 0.035), (185.4, 0.012)]:
        final += amp * np.sin(2 * np.pi * freq * x)
    final *= np.minimum(1.0, x / 0.7) * np.exp(-x * 0.19)
    add_event(track, sr, 65.0, final)

    track[: int(0.18 * sr)] *= np.linspace(0, 1, int(0.18 * sr))
    track[-int(1.2 * sr) :] *= np.linspace(1, 0, int(1.2 * sr))
    peak = max(1.0, np.max(np.abs(track)) / 0.88)
    track = (track / peak * 32767).astype(np.int16)
    stereo = np.column_stack((track, np.roll(track, 19))).reshape(-1)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(sr)
        handle.writeframes(stereo.tobytes())


def srt_timestamp(seconds: float) -> str:
    milliseconds = round(seconds * 1000)
    hours, milliseconds = divmod(milliseconds, 3_600_000)
    minutes, milliseconds = divmod(milliseconds, 60_000)
    secs, milliseconds = divmod(milliseconds, 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{milliseconds:03d}"


def write_srt(lines: list[dict], path: Path) -> None:
    blocks = []
    for index, item in enumerate(lines):
        next_start = lines[index + 1]["start"] if index + 1 < len(lines) else 65.0
        duration = max(2.4, len(item["text"]) * 0.255)
        end = min(next_start - 0.25, item["start"] + duration)
        blocks.append(f"{index + 1}\n{srt_timestamp(item['start'])} --> {srt_timestamp(end)}\n{item['text']}\n")
    path.write_text("\n".join(blocks), encoding="utf-8-sig")


def run(command: list[str]) -> None:
    subprocess.run(command, check=True)


def render_video(lines: list[dict], silent_video: Path) -> None:
    sources = load_sources()
    title_bg = title_background(sources)
    vignette = make_vignette()
    scanlines = make_scanlines()
    grains = make_grain_frames()

    command = [
        FFMPEG,
        "-y",
        "-f",
        "rawvideo",
        "-vcodec",
        "rawvideo",
        "-pix_fmt",
        "rgb24",
        "-s",
        f"{W}x{H}",
        "-r",
        str(FPS),
        "-i",
        "-",
        "-an",
        "-c:v",
        "libx264",
        "-preset",
        "medium",
        "-crf",
        "17",
        "-pix_fmt",
        "yuv420p",
        "-movflags",
        "+faststart",
        str(silent_video),
    ]
    process = subprocess.Popen(command, stdin=subprocess.PIPE)
    assert process.stdin is not None
    try:
        for frame_index in range(TOTAL_FRAMES):
            t = frame_index / FPS
            frame = render_scene(t, sources, title_bg)
            frame = add_subtitle(frame, subtitle_for_time(t, lines))
            frame = apply_finish(frame, frame_index, vignette, scanlines, grains)
            process.stdin.write(np.asarray(frame, dtype=np.uint8).tobytes())
            if frame_index % (FPS * 6) == 0:
                print(f"Rendered {t:05.1f}s / {DURATION:.1f}s", flush=True)
    finally:
        process.stdin.close()
    if process.wait() != 0:
        raise RuntimeError("FFmpeg video encoding failed")


def mix_and_mux(lines: list[dict], soundtrack: Path, silent_video: Path, final_output: Path) -> None:
    command = [FFMPEG, "-y", "-i", str(silent_video), "-i", str(soundtrack)]
    for item in lines:
        command.extend(["-i", str(AUDIO / item["file"])])

    filters = ["[1:a]volume=0.72[music]"]
    mix_inputs = ["[music]"]
    for index, item in enumerate(lines):
        delay = round(float(item["start"]) * 1000)
        input_index = index + 2
        label = f"vo{index}"
        filters.append(
            f"[{input_index}:a]highpass=f=78,lowpass=f=10500,"
            f"acompressor=threshold=-18dB:ratio=2.4:attack=8:release=90,"
            f"volume=1.18,adelay={delay}|{delay}[{label}]"
        )
        mix_inputs.append(f"[{label}]")
    filters.append(
        "".join(mix_inputs)
        + f"amix=inputs={len(mix_inputs)}:duration=longest:dropout_transition=0:normalize=0,"
        + "alimiter=limit=0.94:attack=5:release=80,"
        + "loudnorm=I=-18:TP=-1.5:LRA=7[aout]"
    )
    command.extend(
        [
            "-filter_complex",
            ";".join(filters),
            "-map",
            "0:v:0",
            "-map",
            "[aout]",
            "-c:v",
            "copy",
            "-c:a",
            "aac",
            "-b:a",
            "256k",
            "-ar",
            "48000",
            "-t",
            str(DURATION),
            "-movflags",
            "+faststart",
            str(final_output),
        ]
    )
    run(command)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    AUDIO.mkdir(parents=True, exist_ok=True)
    timing = json.loads((AUDIO / "narration_timing.json").read_text(encoding="utf-8"))
    lines = timing["lines"]
    missing = [item["file"] for item in lines if not (AUDIO / item["file"]).exists()]
    if missing:
        raise FileNotFoundError(f"Missing voice clips: {missing}. Run generate_narration.py first.")

    soundtrack = AUDIO / "original_ambient_score.wav"
    silent_video = OUTPUT / "_clause13_silent.mp4"
    final_output = OUTPUT / "clause13_official_trailer_1080p.mp4"
    srt_output = OUTPUT / "clause13_official_trailer_1080p.srt"

    print("Generating original soundtrack...", flush=True)
    generate_soundtrack(soundtrack)
    write_srt(lines, srt_output)
    print("Rendering picture...", flush=True)
    render_video(lines, silent_video)
    print("Mixing narration and final audio...", flush=True)
    mix_and_mux(lines, soundtrack, silent_video, final_output)
    silent_video.unlink(missing_ok=True)
    print(f"Done: {final_output}", flush=True)


if __name__ == "__main__":
    main()
