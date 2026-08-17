"""Render the clarity-first 68-second Clause 13 gameplay trailer."""

from __future__ import annotations

import json
import math
import subprocess
import wave
from pathlib import Path

import imageio_ffmpeg
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFont


ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parent
CAPTURES = ROOT / "captures"
AUDIO = ROOT / "audio"
OUTPUT = ROOT / "output"
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()

W, H = 1920, 1080
FPS = 30
DURATION = 68.0
TOTAL_FRAMES = int(DURATION * FPS)

FONT_SERIF = Path(r"C:\Windows\Fonts\NotoSerifSC-VF.ttf")
FONT_SANS = Path(r"C:\Windows\Fonts\NotoSansSC-VF.ttf")
FONT_SANS_BOLD = Path(r"C:\Windows\Fonts\msyhbd.ttc")

CREAM = (229, 221, 204)
AMBER = (211, 173, 82)
MUTED = (143, 148, 141)
BLACK = (3, 5, 5)
RESAMPLE = Image.Resampling.LANCZOS


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size=size)


FONTS = {
    "clock": font(FONT_SANS, 20),
    "ai": font(FONT_SANS_BOLD, 74),
    "ai_detail": font(FONT_SANS, 34),
    "twist": font(FONT_SERIF, 92),
    "title_cn": font(FONT_SERIF, 126),
    "title_en": font(FONT_SANS_BOLD, 30),
    "tagline": font(FONT_SERIF, 34),
}


def clamp(value: float, low: float = 0.0, high: float = 1.0) -> float:
    return min(high, max(low, value))


def ease(value: float) -> float:
    value = clamp(value)
    return value * value * (3.0 - 2.0 * value)


def text_alpha(t: float, start: float, end: float, fade: float = 0.45) -> int:
    return round(255 * min(ease((t - start) / fade), ease((end - t) / fade)))


def load_sources() -> dict[str, Image.Image]:
    paths = {
        "rain_art": PROJECT / "assets/encounters/rain_guest_v1.png",
        "tailor_art": PROJECT / "assets/encounters/shadow_tailor_v1.png",
        "red_art": PROJECT / "assets/encounters/red_rescue_v1.png",
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
            image = ImageEnhance.Contrast(image).enhance(1.10)
            image = ImageEnhance.Brightness(image).enhance(0.82)
        else:
            image = ImageEnhance.Contrast(image).enhance(1.025)
            image = ImageEnhance.Brightness(image).enhance(0.95)
        sources[name] = image
    return sources


def focus(source: Image.Image, cx: float = 0.5, cy: float = 0.5, zoom: float = 1.0) -> Image.Image:
    sw, sh = source.size
    crop_w = max(2, round(sw / zoom))
    crop_h = max(2, round(sh / zoom))
    left = round(clamp(cx, 0.0, 1.0) * sw - crop_w / 2)
    top = round(clamp(cy, 0.0, 1.0) * sh - crop_h / 2)
    left = max(0, min(sw - crop_w, left))
    top = max(0, min(sh - crop_h, top))
    return source.crop((left, top, left + crop_w, top + crop_h)).resize((W, H), RESAMPLE)


def art_cover(source: Image.Image, zoom: float = 1.0, cy: float = 0.46) -> Image.Image:
    sw, sh = source.size
    scale = max(W / sw, H / sh) * zoom
    rw, rh = round(sw * scale), round(sh * scale)
    resized = source.resize((rw, rh), RESAMPLE)
    left = max(0, (rw - W) // 2)
    top = round(cy * rh - H / 2)
    top = max(0, min(rh - H, top))
    return resized.crop((left, top, left + W, top + H))


def darken(image: Image.Image, opacity: int) -> Image.Image:
    return Image.blend(image, Image.new("RGB", image.size, BLACK), opacity / 255.0)


def add_centered_text(
    image: Image.Image,
    position: tuple[int, int],
    value: str,
    selected_font: ImageFont.FreeTypeFont,
    color: tuple[int, int, int],
    alpha: int,
    stroke: int = 0,
) -> Image.Image:
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.text(
        position,
        value,
        font=selected_font,
        fill=color + (alpha,),
        anchor="mm",
        stroke_width=stroke,
        stroke_fill=(0, 0, 0, min(220, alpha)),
    )
    return Image.alpha_composite(image.convert("RGBA"), layer).convert("RGB")


def opening(t: float) -> Image.Image:
    frame = Image.new("RGB", (W, H), BLACK)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    slit_alpha = round(34 * ease((t - 0.25) / 1.15))
    draw.rectangle((956, 120, 963, 960), fill=AMBER + (slit_alpha,))
    alpha = round(165 * ease((t - 1.05) / 0.65))
    draw.text((W // 2, 996), "02:13", font=FONTS["clock"], fill=MUTED + (alpha,), anchor="mm")
    return Image.alpha_composite(frame.convert("RGBA"), layer).convert("RGB")


def ai_card(t: float, source: Image.Image) -> Image.Image:
    p = (t - 23.10) / 2.30
    frame = art_cover(source, 1.42 + 0.025 * p, 0.43)
    frame = darken(frame, 205)
    alpha = text_alpha(t, 23.10, 25.40, 0.36)
    frame = add_centered_text(frame, (W // 2, 438), "AI NPC", FONTS["ai"], AMBER, alpha)
    frame = add_centered_text(frame, (W // 2, 562), "会说谎  ·  会试探  ·  会记住", FONTS["ai_detail"], CREAM, round(alpha * 0.92))
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.line((710, 500, 1210, 500), fill=AMBER + (round(alpha * 0.55),), width=2)
    return Image.alpha_composite(frame.convert("RGBA"), layer).convert("RGB")


def twist_card(t: float, source: Image.Image) -> Image.Image:
    p = (t - 56.0) / 4.8
    frame = art_cover(source, 1.14 + 0.035 * p, 0.45)
    frame = darken(frame, 135)
    alpha = text_alpha(t, 56.20, 60.55, 0.52)
    frame = add_centered_text(frame, (W // 2, H // 2), "非人  ≠  伪人", FONTS["twist"], CREAM, alpha, 2)
    return frame


def title_card(t: float, source: Image.Image) -> Image.Image:
    p = (t - 60.8) / 7.2
    frame = art_cover(source, 1.62 + 0.025 * p, 0.42)
    frame = darken(frame, 207)
    alpha = round(250 * ease((t - 60.95) / 0.75))
    frame = add_centered_text(frame, (W // 2, 402), "第十三条款", FONTS["title_cn"], CREAM, alpha, 2)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.line((650, 504, 1270, 504), fill=AMBER + (round(alpha * 0.66),), width=2)
    draw.text((W // 2, 564), "CLAUSE 13", font=FONTS["title_en"], fill=AMBER + (alpha,), anchor="mm")
    draw.text((W // 2, 685), "查清，它是谁。", font=FONTS["tagline"], fill=MUTED + (round(alpha * 0.94),), anchor="mm")
    return Image.alpha_composite(frame.convert("RGBA"), layer).convert("RGB")


def render_scene(t: float, sources: dict[str, Image.Image]) -> Image.Image:
    if t < 2.0:
        return opening(t)
    if t < 7.2:
        p = (t - 2.0) / 5.2
        return focus(sources["rain_ui"], 0.5, 0.5, 1.0 + 0.018 * p)
    if t < 12.4:
        p = (t - 7.2) / 5.2
        return focus(sources["shadow_contract"], 0.83, 0.46, 1.58 + 0.025 * p)
    if t < 18.2:
        p = (t - 12.4) / 5.8
        return focus(sources["training_ui"], 0.5, 0.5, 1.0 + 0.018 * p)
    if t < 19.85:
        p = (t - 18.2) / 1.65
        return focus(sources["rain_evidence"], 0.16, 0.48, 1.66 + 0.025 * p)
    if t < 21.48:
        p = (t - 19.85) / 1.63
        return focus(sources["rain_ui"], 0.50, 0.80, 1.57 + 0.025 * p)
    if t < 23.10:
        p = (t - 21.48) / 1.62
        return focus(sources["rain_evidence"], 0.17, 0.32, 1.72 + 0.025 * p)
    if t < 25.40:
        return ai_card(t, sources["rain_art"])
    if t < 28.95:
        p = (t - 25.40) / 3.55
        return focus(sources["rain_ui"], 0.50, 0.77, 1.50 + 0.025 * p)
    if t < 32.55:
        p = (t - 28.95) / 3.60
        return focus(sources["red_ui"], 0.50, 0.77, 1.50 + 0.025 * p)
    if t < 34.95:
        p = (t - 32.55) / 2.40
        return darken(art_cover(sources["rain_art"], 1.10 + 0.028 * p, 0.43), 38)
    if t < 37.35:
        p = (t - 34.95) / 2.40
        return darken(art_cover(sources["tailor_art"], 1.10 + 0.028 * p, 0.43), 42)
    if t < 39.75:
        p = (t - 37.35) / 2.40
        return darken(art_cover(sources["red_art"], 1.10 + 0.028 * p, 0.43), 40)
    if t < 44.90:
        p = (t - 39.75) / 5.15
        return focus(sources["shadow_contract"], 0.83, 0.46, 1.58 + 0.025 * p)
    if t < 49.70:
        p = (t - 44.90) / 4.80
        return focus(sources["red_contract"], 0.82, 0.46, 1.56 + 0.025 * p)
    if t < 53.95:
        p = (t - 49.70) / 4.25
        return focus(sources["red_contract"], 0.83, 0.82, 1.88 + 0.035 * p)
    if t < 56.0:
        p = (t - 53.95) / 2.05
        return darken(art_cover(sources["red_art"], 1.10 + 0.018 * p, 0.45), round(55 + 55 * p))
    if t < 60.8:
        return twist_card(t, sources["red_art"])
    return title_card(t, sources["rain_art"])


def make_vignette() -> Image.Image:
    yy, xx = np.mgrid[0:H, 0:W]
    nx = (xx - W / 2) / (W / 2)
    ny = (yy - H / 2) / (H / 2)
    radius = np.sqrt(nx * nx + ny * ny)
    alpha = np.clip((radius - 0.58) / 0.62, 0, 1) ** 1.8
    alpha = (alpha * 88).astype(np.uint8)
    rgba = np.zeros((H, W, 4), dtype=np.uint8)
    rgba[..., 3] = alpha
    return Image.fromarray(rgba, "RGBA")


def make_grain_frames() -> list[Image.Image]:
    rng = np.random.default_rng(1313)
    frames = []
    for _ in range(6):
        noise = rng.normal(128, 24, (90, 160)).clip(0, 255).astype(np.uint8)
        large = Image.fromarray(noise, "L").resize((W, H), Image.Resampling.BILINEAR)
        frames.append(Image.merge("RGBA", (large, large, large, Image.new("L", (W, H), 7))))
    return frames


def apply_finish(image: Image.Image, frame_index: int, vignette: Image.Image, grains: list[Image.Image]) -> Image.Image:
    rgba = Image.alpha_composite(image.convert("RGBA"), vignette)
    rgba = Image.alpha_composite(rgba, grains[frame_index % len(grains)])
    draw = ImageDraw.Draw(rgba)
    draw.rectangle((0, 0, W, 28), fill=(0, 0, 0, 238))
    draw.rectangle((0, H - 28, W, H), fill=(0, 0, 0, 238))
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

    # One continuous room tone, with distinct acts instead of a constant wall of effects.
    track = (
        0.047 * np.sin(2 * np.pi * 38.0 * t)
        + 0.026 * np.sin(2 * np.pi * 57.0 * t + 0.55 * np.sin(2 * np.pi * 0.052 * t))
        + 0.013 * np.sin(2 * np.pi * 86.0 * t)
    )
    white = rng.normal(0, 1, n)
    low = np.convolve(white, np.ones(180) / 180, mode="same")
    track += 0.018 * low

    for knock_time, gain in [(0.58, 0.54), (1.31, 0.43)]:
        x = np.arange(int(0.78 * sr)) / sr
        knock = gain * np.exp(-x * 11.5) * (
            np.sin(2 * np.pi * (67 - 17 * x) * x) + 0.31 * np.sin(2 * np.pi * 129 * x)
        )
        knock += gain * 0.075 * rng.normal(0, 1, len(x)) * np.exp(-x * 36.0)
        add_event(track, sr, knock_time, knock)

    # Sparse edit punctuation. Major act changes are stronger than shot changes.
    impacts = [2.0, 7.2, 12.4, 18.2, 23.1, 25.4, 32.55, 39.75, 44.9, 49.7, 56.0, 60.8]
    for index, beat in enumerate(impacts):
        x = np.arange(int(0.55 * sr)) / sr
        gain = 0.17 if beat in (2.0, 23.1, 39.75, 56.0, 60.8) else 0.085
        freq = 45.0 + (index % 3) * 6.0
        impact = gain * np.exp(-x * 8.5) * np.sin(2 * np.pi * (freq - 14 * x) * x)
        add_event(track, sr, beat, impact)

    for pulse_time in np.arange(13.0, 22.8, 1.32):
        x = np.arange(int(0.30 * sr)) / sr
        pulse = 0.042 * np.exp(-x * 17.0) * np.sin(2 * np.pi * 61.0 * x)
        add_event(track, sr, float(pulse_time), pulse)

    for ping_time, freq in [(40.35, 880), (42.05, 1040), (43.75, 1230), (46.10, 980)]:
        x = np.arange(int(0.45 * sr)) / sr
        ping = 0.047 * np.exp(-x * 9.0) * (
            np.sin(2 * np.pi * freq * x) + 0.34 * np.sin(2 * np.pi * freq * 1.49 * x)
        )
        add_event(track, sr, ping_time, ping)

    for beat in np.arange(49.9, 56.0, 1.02):
        x = np.arange(int(0.38 * sr)) / sr
        heart = 0.085 * np.exp(-x * 19.0) * np.sin(2 * np.pi * 53 * x)
        add_event(track, sr, float(beat), heart)

    # Brief vacuum before the twist, then a restrained title chord.
    track[int(54.0 * sr) : int(56.0 * sr)] *= np.linspace(1.0, 0.22, int(2.0 * sr))
    x = np.arange(int(7.2 * sr)) / sr
    chord = np.zeros_like(x)
    for freq, amp in [(41.2, 0.085), (61.8, 0.048), (92.7, 0.029), (185.4, 0.010)]:
        chord += amp * np.sin(2 * np.pi * freq * x)
    chord *= np.minimum(1.0, x / 0.85) * np.exp(-x * 0.17)
    add_event(track, sr, 60.8, chord)

    track[: int(0.16 * sr)] *= np.linspace(0, 1, int(0.16 * sr))
    track[-int(1.25 * sr) :] *= np.linspace(1, 0, int(1.25 * sr))
    peak = max(1.0, np.max(np.abs(track)) / 0.88)
    track = (track / peak * 32767).astype(np.int16)
    stereo = np.column_stack((track, np.roll(track, 23))).reshape(-1)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(sr)
        handle.writeframes(stereo.tobytes())


def run(command: list[str]) -> None:
    subprocess.run(command, check=True)


def render_video(silent_video: Path, poster: Path) -> None:
    sources = load_sources()
    vignette = make_vignette()
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
        "18",
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
            frame = render_scene(t, sources)
            frame = apply_finish(frame, frame_index, vignette, grains)
            if frame_index == round(4.5 * FPS):
                frame.save(poster, quality=94, subsampling=0)
            process.stdin.write(np.asarray(frame, dtype=np.uint8).tobytes())
            if frame_index % (FPS * 5) == 0:
                print(f"Rendered {t:05.1f}s / {DURATION:.1f}s", flush=True)
    finally:
        process.stdin.close()
    if process.wait() != 0:
        raise RuntimeError("FFmpeg video encoding failed")


def mix_and_mux(lines: list[dict], soundtrack: Path, silent_video: Path, final_output: Path) -> None:
    command = [FFMPEG, "-y", "-i", str(silent_video), "-i", str(soundtrack)]
    for item in lines:
        command.extend(["-i", str(AUDIO / item["file"])])

    filters = ["[1:a]volume=0.64[music]"]
    mix_inputs = ["[music]"]
    for index, item in enumerate(lines):
        delay = round(float(item["start"]) * 1000)
        input_index = index + 2
        label = f"vo{index}"
        filters.append(
            f"[{input_index}:a]highpass=f=78,lowpass=f=10500,"
            f"acompressor=threshold=-18dB:ratio=2.2:attack=8:release=95,"
            f"volume=1.20,adelay={delay}|{delay}[{label}]"
        )
        mix_inputs.append(f"[{label}]")
    filters.append(
        "".join(mix_inputs)
        + f"amix=inputs={len(mix_inputs)}:duration=longest:dropout_transition=0:normalize=0,"
        + "alimiter=limit=0.94:attack=5:release=80,loudnorm=I=-18:TP=-1.5:LRA=7[aout]"
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
    timing_path = AUDIO / "narration_v2_timing.json"
    if not timing_path.exists():
        raise FileNotFoundError("Run generate_narration_v2.py first.")
    lines = json.loads(timing_path.read_text(encoding="utf-8"))["lines"]
    missing = [item["file"] for item in lines if not (AUDIO / item["file"]).exists()]
    if missing:
        raise FileNotFoundError(f"Missing voice clips: {missing}. Run generate_narration_v2.py first.")

    soundtrack = AUDIO / "v2_original_ambient_score.wav"
    silent_video = OUTPUT / "_clause13_v2_silent.mp4"
    final_output = OUTPUT / "clause13_official_trailer_v2_1080p.mp4"
    poster = OUTPUT / "clause13_trailer_v2_poster.jpg"

    print("Generating structured ambient score...", flush=True)
    generate_soundtrack(soundtrack)
    print("Rendering clarity-first picture...", flush=True)
    render_video(silent_video, poster)
    print("Mixing narration and final audio...", flush=True)
    mix_and_mux(lines, soundtrack, silent_video, final_output)
    silent_video.unlink(missing_ok=True)
    print(f"Done: {final_output}", flush=True)


if __name__ == "__main__":
    main()
