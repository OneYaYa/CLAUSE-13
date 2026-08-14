# CLAUSE 13 / 第十三条款

一个独立的 Godot 4.6 AI NPC 谈判解谜原型。玩家是门槛事务局的夜间公证员：与超自然来客自由对话，套出它真正的欲望和限制，再把“进入范围 / 交换代价 / 离开条件”写成会被现实逐字执行的契约。

这不是聊天框套皮。NPC 的对白可以自由生成，但证据、信任、谈判轮次、条款接受度和结局始终由本地确定性模拟器裁决。

![当前原型界面](artifacts/clause13_preview.png)

## 已实现

- 3 个可独立游玩的短案件，每关约 6–9 分钟
- 自由中文输入、NPC 情绪与跨轮记忆、信任/压迫变化
- 可查阅的访客档案：身份记录、别名、异常分类、旧案行为、风险标签与建议问法
- 通过身份、动机、代价、范围、期限等话题解锁可验证证据与档案矛盾
- 三槽契约编辑器；NPC 会偏爱对自己有利但对玩家危险的条款
- 完整成功、带代价成功、契约漏洞失败三类结局和评级
- 三套原创第一人称门口遭遇场景，带轻微视差、灯光闪烁、胶片颗粒和暗角
- 离线本地人格可直接玩；可选在线模型增强，断线自动降级
- Godot 核心 40 项检查、Python 对话服务 3 项检查

## 直接运行

用 Godot 4.6 打开本目录的 `project.godot`，按 F6/F5 即可。没有网络或 API Key 时，游戏会自动使用本地人格规则，全部关卡和结局仍可正常完成。

本机也可以从命令行运行：

```powershell
& 'C:\path\to\Godot_v4.6.3-stable_win64.exe' --path 'C:\path\to\clause13'
```

## 开启在线 AI NPC

1. 复制 `.env.example` 为 `.env`。
2. 在 `.env` 中填写 `OPENAI_API_KEY`；密钥只保存在本机 Python 服务，不会写入 Godot 客户端。
3. 启动服务：

```powershell
.\start_dialogue_server.ps1
```

4. 再启动 Godot。右下角出现 `AI: ONLINE · WORLD: LOCAL` 即表示人格增强已连接。

服务使用 OpenAI Responses API 的严格 JSON Schema 输出。默认模型在 `.env.example` 中配置，可用 `CLAUSE13_MODEL` 替换。服务不可用时，当前回合会安全降级到本地人格；模型永远不能签署契约或修改游戏状态。

## 玩法

1. 阅读左侧人物档案；在“人物档案 / 现场证据 / 说法核验”之间切换。
2. 在中间自由输入问题；安抚能提高信任，威胁会提高门槛压力。
3. 把新口供与已确认事实对照，选择右侧三项条款。
4. 点击“提出草案”。对方若拒绝，可继续谈判或放宽条件。
5. 对方接受后才可“签署并执行”。签署不可撤回。

最容易被 NPC 接受的草案，通常不是最安全的草案。好结局依赖玩家既读懂事实，也读懂对方。

## 测试

```powershell
# Godot 确定性核心
godot --headless --path . res://tests/case_simulation_test.tscn

# Python AI 服务契约
python -m unittest discover -s tests -p 'test_*.py' -v
```

生成一张 1280×720 界面预览：

```powershell
godot --path . --resolution 1280x720 res://tools/capture_preview.tscn
```

## 目录

```text
clause13/
├─ data/campaign.json                 # 三关内容、私有事实、条款与结局
├─ scenes/main.tscn                   # 入口场景
├─ scripts/core/case_simulation.gd    # 唯一权威世界状态
├─ scripts/services/                  # 本地人格与可选在线服务
├─ assets/encounters/                 # 三关原创访客场景与美术提示词
├─ scripts/ui/                        # 第一人称审问 UI 与模拟影像效果
├─ server.py                          # 可选 Responses API 对话边车
├─ tests/                             # Godot / Python 自动化检查
└─ DESIGN.md                          # 背景、研究结论与扩展路线
```
