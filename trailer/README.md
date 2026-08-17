# 《第十三条款》宣传片制作文件

- `clause13_trailer_1080p.mp4`：用于 GitHub 展示的清晰叙事版成片
- `clause13_trailer_poster.jpg`：README 可点击宣传片封面
- `clause13_trailer_zh-CN.srt`：中文字幕
- `output/clause13_official_trailer_v2_1080p.mp4`：68 秒 1080p 制作母版
- `trailer_plan.md`：导演阐述、时间线与最终旁白
- `render_trailer_v2.py`：可重复生成新版成片的剪辑、动效和原创音效脚本
- `generate_narration_v2.py`：根据中文字幕生成中文旁白的脚本
- `captures/`：由 Godot 真实状态机自动生成的实机画面
- `audio/`：旁白分轨和原创氛围配乐

成片规格：1920×1080、30 fps、H.264 High、AAC 48 kHz 双声道、68 秒。画面不烧录整段字幕，保持实机 UI 清晰；中文字幕以独立 SRT 提供。

重新生成：

```powershell
python .\trailer\generate_narration_v2.py
python .\trailer\render_trailer_v2.py
```

成片只使用项目内原创视觉、程序生成的原创氛围音乐与本项目旁白，不包含参考游戏素材。
