# 《第十三条款》宣传片制作文件

- `clause13_trailer_1080p.mp4`：用于 GitHub 展示的 1080p Web 优化版
- `clause13_trailer_poster.jpg`：README 可点击宣传片封面
- `clause13_trailer_zh-CN.srt`：中文字幕
- `output/clause13_official_trailer_1080p.mp4`：72 秒 1080p 成片
- `output/clause13_official_trailer_1080p.srt`：旁白字幕
- `trailer_plan.md`：导演阐述、时间线与最终旁白
- `render_trailer.py`：可重复生成成片的剪辑、动效和原创音效脚本
- `generate_narration.py`：中文旁白生成脚本
- `captures/`：由 Godot 真实状态机自动生成的实机画面
- `audio/`：旁白分轨和原创氛围配乐

成片规格：1920×1080、24 fps、H.264 High、AAC 48 kHz 双声道、72 秒；最终混音约 -19 LUFS / -1.4 dBTP。

重新生成：

```powershell
python .\trailer\generate_narration.py
python .\trailer\render_trailer.py
```

成片只使用项目内原创视觉、程序生成的原创氛围音乐与本项目旁白，不包含参考游戏素材。
