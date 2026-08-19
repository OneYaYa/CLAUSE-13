<p align="center">
  <a href="README.md">简体中文</a> · <strong>English</strong>
</p>

<p align="center">
  <img src="assets/branding/clause13_icon.png" width="180" alt="CLAUSE 13 game icon">
</p>

<h1 align="center">CLAUSE 13 / 第十三条款</h1>

<p align="center"><strong>Do not decide whether it looks human. Find out who it is.</strong></p>

CLAUSE 13 is a standalone Godot 4.6 AI-NPC identity-verification puzzle prototype. As the night verifier for the Threshold Affairs Bureau, you inspect records, freely question visitors outside the door, cross-check their testimony, and decide whether each one is a trusted visitor or an impostor.

This is more than a chat interface. NPC dialogue may be generated freely, but evidence unlocks, verification rounds, protocol results, and the final identity answer are always controlled by a deterministic local simulator.

## Trailer

[![CLAUSE 13 1080p gameplay trailer](trailer/clause13_trailer_poster.jpg)](trailer/clause13_trailer_1080p.mp4)

<p align="center">
  <strong><a href="trailer/clause13_trailer_1080p.mp4">▶ Play / download the 1080p trailer</a></strong>
  ·
  <a href="trailer/clause13_trailer_zh-CN.srt">Chinese subtitles</a>
</p>

![Current prototype interface](artifacts/clause13_preview.png)

![Tutorial case](artifacts/tutorial_preview.png)

## Features

- One playable tutorial followed automatically by three short cases
- Free-form Chinese input, NPC emotions and cross-turn memory, plus changing trust and pressure
- Browsable visitor dossiers with identity records, aliases, anomaly class, prior behavior, risk labels, and suggested questions
- Verifiable evidence and record contradictions unlocked through identity, motive, cost, scope, and deadline topics
- A three-slot Verification Protocol that tests scope, cost, and exit conditions without deciding the case for you
- Two final judgments only: trusted visitor or impostor; correct decisions advance, while mistakes keep you in the case for review
- Four original first-person doorstep scenes with restrained parallax and light vignetting
- Fully playable offline personalities with optional online model enhancement and automatic fallback
- Versioned context compilation, hard knowledge locks, event-sourced subjective memory, and stale-response rejection
- Structured Outputs, citation/action allowlist validation, and prompt traces
- Automated Godot core, UI-flow, and Python dialogue-service checks

For module boundaries, data design, context compilation, failure handling, testing strategy, and a portfolio-ready technical overview, see [AI NPC Engineering](AI_NPC_ENGINEERING.md).

## Run the Game

Open `project.godot` with Godot 4.6 and press F6/F5. With no network connection or API key, the game automatically uses its local personality rules; all cases and endings remain available.

From PowerShell:

```powershell
& 'C:\path\to\Godot_v4.6.3-stable_win64.exe' --path 'C:\path\to\clause13'
```

## Optional Online AI NPCs

1. Copy `.env.example` to `.env`.
2. Add `OPENAI_API_KEY`. The key stays in the local Python service and is never written to the Godot client.
3. Start the service:

```powershell
.\start_dialogue_server.ps1
```

4. Start Godot. `AI: ONLINE · WORLD: LOCAL` in the lower-right corner confirms that personality enhancement is connected.

The service uses the OpenAI Responses API with a strict JSON Schema. Configure the default model in `.env.example` or override it with `CLAUSE13_MODEL`. If the service is unavailable, the current turn safely falls back to the local personality. The model can never modify evidence, protocol results, or identity answers.

## How to Play

1. Read the dossier on the left and switch among the dossier, scene evidence, and testimony checks.
2. Ask free-form questions and cross-check answers against schedules, old cases, sensors, and other records.
3. When in doubt, run the Verification Protocol on the right and observe whether the visitor accepts its three objective conditions.
4. Treat the protocol as evidence, not a verdict. Submit either `Trusted Visitor` or `Impostor`.
5. A correct judgment advances to the next case; an incorrect one keeps the case open for more questioning.

In this setting, an impostor is a substitute who uses a stolen identity, mimicry, or false intent to obtain an invitation. It does not mean every non-human visitor is hostile; legally registered anomalous beings can still be trusted visitors.

## Tests

```powershell
# Deterministic Godot core
godot --headless --path . res://tests/case_simulation_test.tscn

# Python AI-service contract
python -m unittest discover -s tests -p 'test_*.py' -v
```

Generate a 1280×720 interface preview:

```powershell
godot --path . --resolution 1280x720 res://tools/capture_preview.tscn
```

## Project Structure

```text
clause13/
├─ data/campaign.json                 # Tutorial, three cases, private identities, conditions
├─ scenes/main.tscn                   # Entry scene
├─ scripts/core/case_simulation.gd    # Authoritative world state
├─ scripts/services/                  # Local personalities, context compiler, online service
├─ assets/encounters/                 # Original visitor scenes and art prompts
├─ scripts/ui/                        # First-person interview UI and simulated video
├─ server.py                          # Optional Responses API sidecar
├─ tests/                             # Godot and Python checks
├─ DESIGN.md                          # Background, research, and extension roadmap
└─ AI_NPC_ENGINEERING.md              # Detailed AI-NPC engineering design
```
