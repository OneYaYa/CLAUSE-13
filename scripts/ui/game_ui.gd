class_name Clause13UI
extends Control


signal case_selected(case_id: String)
signal player_submitted(text: String)
signal clause_selected(slot: String, clause_id: String)
signal propose_requested()
signal sign_requested()
signal restart_requested()
signal next_case_requested()

const ENCOUNTER_TEXTURES := {
	"rain_guest": preload("res://assets/encounters/rain_guest_v1.png"),
	"shadow_tailor": preload("res://assets/encounters/shadow_tailor_v1.png"),
	"red_rescue": preload("res://assets/encounters/red_rescue_v1.png"),
}
const INK := Color("e8dfc8")
const MUTED := Color("aaa187")
const PAPER := Color("19170fef")
const PAPER_LIGHT := Color("211c10f2")
const BLACK_GLASS := Color("080a08e8")
const LINE := Color("716849")
const JADE := Color("8eb9a0")
const AMBER := Color("d5aa5c")
const RED := Color("b65b4f")

var suppress_intro := false
var _snapshot: Dictionary = {}
var _catalog: Array[Dictionary] = []
var _updating := false
var _current_case_id := ""
var _elapsed := 0.0
var _next_flicker := 1.6

var _encounter_background: TextureRect
var _scene_tint: ColorRect
var _flicker: ColorRect
var _scene_fade: ColorRect
var _overlay: ColorRect
var _dossier_panel: PanelContainer
var _contract_panel: PanelContainer
var _case_selector: OptionButton
var _case_title: Label
var _turn_label: Label
var _ward_bar: ProgressBar
var _ward_value: Label
var _trust_bar: ProgressBar
var _pressure_bar: ProgressBar
var _objective: RichTextLabel
var _evidence: RichTextLabel
var _contradictions: RichTextLabel
var _npc_name: Label
var _npc_claim: Label
var _dialogue: RichTextLabel
var _input: LineEdit
var _send: Button
var _prompt_row: HBoxContainer
var _clause_selectors: Dictionary = {}
var _clause_details: Dictionary = {}
var _contract_status: RichTextLabel
var _propose_button: Button
var _sign_button: Button
var _status: Label
var _authority: Label
var _outcome_dialog: AcceptDialog
var _intro_dialog: AcceptDialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _make_theme()
	_build()
	set_process(true)
	set_process_unhandled_key_input(true)
	if not suppress_intro:
		call_deferred("_show_intro")


func configure_cases(catalog: Array[Dictionary], current_case_id: String) -> void:
	_catalog = []
	for item: Dictionary in catalog:
		_catalog.append(item.duplicate(true))
	_current_case_id = current_case_id
	_updating = true
	_case_selector.clear()
	var selected_index := 0
	for index: int in range(_catalog.size()):
		var item := _catalog[index]
		_case_selector.add_item("%02d  %s" % [int(item.get("number", index + 1)), str(item.get("title", ""))])
		_case_selector.set_item_metadata(index, str(item.get("id", "")))
		if str(item.get("id", "")) == current_case_id:
			selected_index = index
	_case_selector.select(selected_index)
	_updating = false


func render(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	var next_case_id := str(snapshot.get("case_id", _current_case_id))
	if next_case_id != _current_case_id or _encounter_background.texture == null:
		_set_encounter(next_case_id)
	_current_case_id = next_case_id
	_case_title.text = "%s\n%s" % [str(snapshot.get("case_title", "未命名案件")), str(snapshot.get("case_subtitle", ""))]
	_turn_label.text = "轮次 %02d / %02d" % [int(snapshot.get("turn", 0)), int(snapshot.get("max_turns", 0))]
	_set_bar(_ward_bar, _ward_value, int(snapshot.get("ward", 0)), JADE)
	_set_bar(_trust_bar, null, int(snapshot.get("trust", 0)), JADE)
	_set_bar(_pressure_bar, null, int(snapshot.get("pressure", 0)), RED)
	var npc: Dictionary = _dict(snapshot.get("npc", {}))
	_npc_name.text = str(npc.get("name", "门外来客"))
	_npc_claim.text = "%s  ·  %s" % [str(npc.get("kind", "未登记")), str(npc.get("claim", "身份待核验"))]
	_objective.text = _profile_text(snapshot)
	_evidence.text = _evidence_text(snapshot)
	_contradictions.text = _contradictions_text(snapshot)
	_dialogue.text = _dialogue_text(snapshot)
	_dialogue.scroll_to_line(maxi(0, _dialogue.get_line_count() - 1))
	_configure_clause_selectors(snapshot)
	_render_contract_status(snapshot)
	_render_prompts(snapshot)
	var terminal := bool(snapshot.get("is_terminal", false))
	_input.editable = not terminal
	_send.disabled = terminal
	_propose_button.disabled = terminal or not bool(snapshot.get("contract_complete", false))
	_sign_button.disabled = terminal or not bool(snapshot.get("contract_accepted", false))
	_status.text = str(snapshot.get("guidance", "等待案件数据。"))
	_status.add_theme_color_override("font_color", MUTED)


func show_result(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_status.text = str(result.get("message", "请求被拒绝。"))
		_status.add_theme_color_override("font_color", RED)
		_pulse_scene(RED, 0.12)
		return
	if result.has("snapshot") and result["snapshot"] is Dictionary:
		render(result["snapshot"] as Dictionary)
	_pulse_scene(Color("d7bd78"), 0.055)


func show_outcome(outcome: String, snapshot: Dictionary) -> void:
	var debrief: Dictionary = _dict(snapshot.get("debrief", {}))
	var contract: Dictionary = _dict(debrief.get("contract", {}))
	_outcome_dialog.title = str(debrief.get("title", "案件封存"))
	_outcome_dialog.dialog_text = "%s\n\n评级：%s　谈判轮次：%s　最终信任：%s\n\n进入范围：%s\n交换代价：%s\n离开条件：%s\n\n%s" % [
		str(debrief.get("body", "契约已经执行。")),
		str(debrief.get("grade", "--")),
		str(debrief.get("turns", "--")),
		str(debrief.get("trust", "--")),
		str(contract.get("scope", "未填写")),
		str(contract.get("price", "未填写")),
		str(contract.get("exit", "未填写")),
		"继续接通下一位来客。" if outcome != "failure" else "可以重开本案，换一种问法和条款组合。",
	]
	_outcome_dialog.ok_button_text = "下一案" if outcome != "failure" else "返回复盘"
	_outcome_dialog.popup_centered(Vector2i(580, 420))


func focus_input() -> void:
	if _input.editable:
		_input.grab_focus()


func set_thinking(active: bool) -> void:
	_input.editable = not active and not bool(_snapshot.get("is_terminal", false))
	_send.disabled = active or bool(_snapshot.get("is_terminal", false))
	_send.text = "聆听……" if active else "发问"
	if active:
		_status.text = "门外的人正在斟酌措辞……世界状态保持冻结。"


func set_ai_status(status: String, detail: String) -> void:
	if is_instance_valid(_authority):
		_authority.text = "NPC %s  /  WORLD LOCAL" % status.to_upper()
		_authority.add_theme_color_override("font_color", JADE if status == "online" else AMBER)
	if not detail.is_empty() and is_instance_valid(_status):
		_status.text = detail


func dismiss_intro() -> void:
	if is_instance_valid(_intro_dialog):
		_intro_dialog.hide()


func _process(delta: float) -> void:
	_elapsed += delta
	if is_instance_valid(_encounter_background):
		var viewport_size := get_viewport_rect().size
		var mouse := get_viewport().get_mouse_position()
		var target := Vector2.ZERO
		if viewport_size.x > 0.0 and viewport_size.y > 0.0:
			target = (mouse / viewport_size - Vector2(0.5, 0.5)) * Vector2(9.0, 5.0)
		var breath := Vector2(sin(_elapsed * 0.31), cos(_elapsed * 0.24)) * 1.4
		_encounter_background.position = Vector2(-30.0, -26.0) - target + breath
	if _elapsed >= _next_flicker:
		_next_flicker = _elapsed + randf_range(1.2, 4.2)
		_flicker_light()


func _build() -> void:
	_build_scene()
	_build_top_bar()
	_build_dossier()
	_build_contract()
	_build_dialogue()
	_build_dialogs()


func _build_scene() -> void:
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	_encounter_background = TextureRect.new()
	_encounter_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_encounter_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_encounter_background.anchor_right = 1.0
	_encounter_background.anchor_bottom = 1.0
	_encounter_background.offset_left = -30.0
	_encounter_background.offset_top = -26.0
	_encounter_background.offset_right = 30.0
	_encounter_background.offset_bottom = 26.0
	_encounter_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_encounter_background)
	_scene_tint = ColorRect.new()
	_scene_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scene_tint.color = Color("07100b22")
	_scene_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scene_tint)
	_flicker = ColorRect.new()
	_flicker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flicker.color = Color(0.0, 0.0, 0.0, 0.0)
	_flicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flicker)
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.material = _make_analog_material()
	add_child(_overlay)
	_scene_fade = ColorRect.new()
	_scene_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scene_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_scene_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scene_fade)
	var top_letterbox := ColorRect.new()
	top_letterbox.color = Color("030302dd")
	top_letterbox.anchor_right = 1.0
	top_letterbox.offset_bottom = 7.0
	top_letterbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_letterbox)
	var bottom_letterbox := ColorRect.new()
	bottom_letterbox.color = Color("030302dd")
	bottom_letterbox.anchor_top = 1.0
	bottom_letterbox.anchor_right = 1.0
	bottom_letterbox.anchor_bottom = 1.0
	bottom_letterbox.offset_top = -7.0
	bottom_letterbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_letterbox)


func _build_top_bar() -> void:
	var panel := _panel(Color("090b09e8"), Color("5f5b43"))
	_place(panel, 16.0, 16.0, -16.0, 72.0)
	add_child(panel)
	var margin := _margin(12, 7)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var mark := Label.new()
	mark.text = "第十三条款\nNIGHT NOTARY"
	mark.add_theme_color_override("font_color", AMBER)
	mark.add_theme_font_size_override("font_size", 13)
	row.add_child(mark)
	_case_selector = OptionButton.new()
	_case_selector.custom_minimum_size.x = 155
	_case_selector.item_selected.connect(_on_case_selected)
	row.add_child(_case_selector)
	_case_title = Label.new()
	_case_title.text = "等待接通\n未登记访客"
	_case_title.custom_minimum_size.x = 160
	_case_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_case_title.add_theme_font_size_override("font_size", 13)
	_case_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_case_title)
	var ward := _inline_meter("门槛", JADE, true)
	row.add_child(ward["root"])
	_ward_bar = ward["bar"] as ProgressBar
	_ward_value = ward["value"] as Label
	var trust := _inline_meter("信任", JADE, false)
	row.add_child(trust["root"])
	_trust_bar = trust["bar"] as ProgressBar
	var pressure := _inline_meter("压迫", RED, false)
	row.add_child(pressure["root"])
	_pressure_bar = pressure["bar"] as ProgressBar
	_turn_label = Label.new()
	_turn_label.text = "轮次 00 / 00"
	_turn_label.add_theme_color_override("font_color", INK)
	_turn_label.add_theme_font_size_override("font_size", 11)
	row.add_child(_turn_label)
	var dossier_toggle := Button.new()
	dossier_toggle.text = "卷宗"
	dossier_toggle.tooltip_text = "显示或收起案卷"
	dossier_toggle.pressed.connect(_toggle_dossier)
	row.add_child(dossier_toggle)
	var contract_toggle := Button.new()
	contract_toggle.text = "契约"
	contract_toggle.tooltip_text = "显示或收起约束文书"
	contract_toggle.pressed.connect(_toggle_contract)
	row.add_child(contract_toggle)
	var restart := Button.new()
	restart.text = "重开"
	restart.tooltip_text = "Ctrl+R"
	restart.pressed.connect(restart_requested.emit)
	row.add_child(restart)


func _build_dossier() -> void:
	_dossier_panel = _panel(PAPER, LINE)
	_dossier_panel.anchor_bottom = 1.0
	_dossier_panel.offset_left = 18.0
	_dossier_panel.offset_top = 86.0
	_dossier_panel.offset_right = 322.0
	_dossier_panel.offset_bottom = -22.0
	add_child(_dossier_panel)
	var margin := _margin(15, 13)
	_dossier_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	heading.add_child(_header("现场案卷 / DOSSIER"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(spacer)
	var classified := Label.new()
	classified.text = "夜班内参"
	classified.add_theme_color_override("font_color", RED)
	classified.add_theme_font_size_override("font_size", 10)
	heading.add_child(classified)
	box.add_child(HSeparator.new())
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 11)
	box.add_child(tabs)
	_objective = RichTextLabel.new()
	_objective.name = "人物档案"
	_objective.bbcode_enabled = true
	_objective.scroll_active = true
	_objective.selection_enabled = true
	tabs.add_child(_objective)
	_evidence = RichTextLabel.new()
	_evidence.name = "现场证据"
	_evidence.bbcode_enabled = true
	_evidence.scroll_active = true
	_evidence.selection_enabled = true
	tabs.add_child(_evidence)
	_contradictions = RichTextLabel.new()
	_contradictions.name = "说法核验"
	_contradictions.bbcode_enabled = true
	_contradictions.scroll_active = true
	_contradictions.selection_enabled = true
	tabs.add_child(_contradictions)
	var stamp := Label.new()
	stamp.text = "不要相信称谓\n只相信代价"
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.add_theme_color_override("font_color", Color("9c4e45"))
	stamp.add_theme_font_size_override("font_size", 11)
	box.add_child(stamp)


func _build_contract() -> void:
	_contract_panel = _panel(PAPER_LIGHT, Color("826a44"))
	_contract_panel.anchor_left = 1.0
	_contract_panel.anchor_right = 1.0
	_contract_panel.anchor_bottom = 1.0
	_contract_panel.offset_left = -348.0
	_contract_panel.offset_top = 86.0
	_contract_panel.offset_right = -18.0
	_contract_panel.offset_bottom = -22.0
	add_child(_contract_panel)
	var margin := _margin(15, 12)
	_contract_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	heading.add_child(_header("约束文书 / BINDING DRAFT"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(spacer)
	var clause := Label.new()
	clause.text = "§13"
	clause.add_theme_color_override("font_color", RED)
	clause.add_theme_font_size_override("font_size", 18)
	heading.add_child(clause)
	var explain := Label.new()
	explain.text = "邀请会被现实逐字执行。三处空白，缺一不可。"
	explain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explain.add_theme_color_override("font_color", MUTED)
	explain.add_theme_font_size_override("font_size", 11)
	box.add_child(explain)
	var slot_names := {"scope": "一、准入范围", "price": "二、交换代价", "exit": "三、离开条件"}
	for slot: String in ["scope", "price", "exit"]:
		box.add_child(_header(str(slot_names[slot])))
		var selector := OptionButton.new()
		selector.custom_minimum_size.y = 34
		selector.item_selected.connect(_on_clause_selected.bind(slot))
		box.add_child(selector)
		_clause_selectors[slot] = selector
		var detail := Label.new()
		detail.custom_minimum_size.y = 35
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_color_override("font_color", MUTED)
		detail.add_theme_font_size_override("font_size", 10)
		box.add_child(detail)
		_clause_details[slot] = detail
	box.add_child(HSeparator.new())
	_contract_status = RichTextLabel.new()
	_contract_status.bbcode_enabled = true
	_contract_status.custom_minimum_size.y = 58
	_contract_status.fit_content = false
	box.add_child(_contract_status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	_propose_button = Button.new()
	_propose_button.text = "递出草案"
	_propose_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_propose_button.pressed.connect(propose_requested.emit)
	buttons.add_child(_propose_button)
	_sign_button = Button.new()
	_sign_button.text = "落印执行"
	_sign_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sign_button.pressed.connect(sign_requested.emit)
	_sign_button.add_theme_color_override("font_color", Color("f1c7a2"))
	buttons.add_child(_sign_button)
	_authority = Label.new()
	_authority.text = "NPC PROBING  /  WORLD LOCAL"
	_authority.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_authority.add_theme_color_override("font_color", AMBER)
	_authority.add_theme_font_size_override("font_size", 9)
	box.add_child(_authority)


func _build_dialogue() -> void:
	var panel := _panel(BLACK_GLASS, Color("555340"))
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -304.0
	panel.offset_top = -210.0
	panel.offset_right = 304.0
	panel.offset_bottom = -20.0
	add_child(panel)
	var margin := _margin(13, 9)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var identity := HBoxContainer.new()
	box.add_child(identity)
	_npc_name = Label.new()
	_npc_name.text = "门外来客"
	_npc_name.add_theme_font_size_override("font_size", 19)
	_npc_name.add_theme_color_override("font_color", AMBER)
	identity.add_child(_npc_name)
	_npc_claim = Label.new()
	_npc_claim.text = "身份待核验"
	_npc_claim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_npc_claim.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_npc_claim.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_npc_claim.add_theme_color_override("font_color", MUTED)
	_npc_claim.add_theme_font_size_override("font_size", 10)
	_npc_claim.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(_npc_claim)
	_dialogue = RichTextLabel.new()
	_dialogue.bbcode_enabled = true
	_dialogue.custom_minimum_size.y = 55
	_dialogue.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue.scroll_active = true
	_dialogue.selection_enabled = true
	box.add_child(_dialogue)
	_prompt_row = HBoxContainer.new()
	_prompt_row.add_theme_constant_override("separation", 5)
	box.add_child(_prompt_row)
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 6)
	box.add_child(input_row)
	_input = LineEdit.new()
	_input.placeholder_text = "对门外的人自由发问：质疑、安抚、欺骗，或谈条件……"
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.text_submitted.connect(_submit.unbind(1))
	input_row.add_child(_input)
	_send = Button.new()
	_send.text = "发问"
	_send.pressed.connect(_submit)
	input_row.add_child(_send)
	_status = Label.new()
	_status.text = "正在接通夜间来客……"
	_status.add_theme_color_override("font_color", MUTED)
	_status.add_theme_font_size_override("font_size", 9)
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(_status)


func _build_dialogs() -> void:
	_outcome_dialog = AcceptDialog.new()
	_outcome_dialog.confirmed.connect(_on_outcome_confirmed)
	add_child(_outcome_dialog)
	_intro_dialog = AcceptDialog.new()
	_intro_dialog.title = "夜班守则：第十三条款"
	_intro_dialog.ok_button_text = "打开窥视孔"
	_intro_dialog.dialog_text = "今夜，门外的每个人都需要你的邀请。\n\n先谈话：称谓可以撒谎，欲望和代价很难。\n再核验：左侧案卷只记录能够确认的痕迹。\n后立约：选择准入范围、交换代价与离开条件。\n\n门一旦打开，现实会逐字执行你签下的内容。"
	add_child(_intro_dialog)


func _show_intro() -> void:
	_intro_dialog.popup_centered(Vector2i(540, 330))


func _set_encounter(case_id: String) -> void:
	_encounter_background.texture = ENCOUNTER_TEXTURES.get(case_id, ENCOUNTER_TEXTURES["rain_guest"])
	match case_id:
		"shadow_tailor":
			_scene_tint.color = Color("080b1024")
		"red_rescue":
			_scene_tint.color = Color("1e080621")
		_:
			_scene_tint.color = Color("07120c20")
	_scene_fade.color = Color(0.0, 0.0, 0.0, 0.88)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_scene_fade, "color", Color(0.0, 0.0, 0.0, 0.0), 0.75)


func _flicker_light() -> void:
	if not is_instance_valid(_flicker):
		return
	var tween := create_tween()
	_flicker.color = Color(0.02, 0.015, 0.005, randf_range(0.08, 0.16))
	tween.tween_property(_flicker, "color", Color(0.0, 0.0, 0.0, 0.0), randf_range(0.07, 0.16))


func _pulse_scene(color: Color, alpha: float) -> void:
	var pulse := color
	pulse.a = alpha
	_flicker.color = pulse
	var tween := create_tween()
	tween.tween_property(_flicker, "color", Color(0.0, 0.0, 0.0, 0.0), 0.22)


func _toggle_dossier() -> void:
	_dossier_panel.visible = not _dossier_panel.visible


func _toggle_contract() -> void:
	_contract_panel.visible = not _contract_panel.visible


func _profile_text(snapshot: Dictionary) -> String:
	var dossier: Dictionary = _dict(snapshot.get("dossier", {}))
	var npc: Dictionary = _dict(snapshot.get("npc", {}))
	var aliases := PackedStringArray()
	for raw: Variant in _array(dossier.get("aliases", [])):
		aliases.append(str(raw))
	var result := "[color=#d5aa5c][font_size=16][b]%s[/b][/font_size][/color]\n" % _escape(str(dossier.get("record_name", npc.get("name", "身份不明"))))
	result += "[color=#8e8773]档案编号[/color]  %s\n" % _escape(str(dossier.get("archive_id", "未建档")))
	result += "[color=#8e8773]已知别名[/color]  %s\n" % _escape(" / ".join(aliases))
	result += "[color=#8e8773]异常分类[/color]  %s\n" % _escape(str(dossier.get("classification", npc.get("kind", "待核验"))))
	result += "[color=#8e8773]登记状态[/color]  %s\n" % _escape(str(dossier.get("registry_status", "记录缺失")))
	result += "[color=#8e8773]上次出现[/color]  %s\n\n" % _escape(str(dossier.get("last_seen", "无记录")))
	result += "[color=#b65b4f][b]风险标签[/b][/color]\n"
	for raw: Variant in _array(dossier.get("risk_flags", [])):
		result += "[color=#c57b67]■[/color] %s　" % _escape(str(raw))
	result += "\n\n[color=#d5aa5c][b]已知行为[/b][/color]"
	for raw: Variant in _array(dossier.get("known_behavior", [])):
		result += "\n[color=#8eb9a0]—[/color] %s" % _escape(str(raw))
	result += "\n\n[color=#d5aa5c][b]建议问法[/b][/color]"
	for raw: Variant in _array(dossier.get("interview_leads", [])):
		result += "\n[color=#8eb9a0]›[/color] %s" % _escape(str(raw))
	result += "\n\n[color=#d5aa5c][b]本夜目标[/b][/color]\n%s\n[color=#8e8773]预计 %d 分钟[/color]" % [
		_escape(str(snapshot.get("objective", ""))), int(snapshot.get("estimated_minutes", 0))
	]
	return result


func _evidence_text(snapshot: Dictionary) -> String:
	var result := "[color=#8e8773]证据只记录可交叉验证的事实；新口供会自动归档。[/color]\n\n"
	for raw: Variant in _array(snapshot.get("evidence", [])):
		var item := raw as Dictionary
		result += "[color=#d5aa5c][b]%s[/b][/color]\n[color=#8e8773]%s[/color]\n%s\n\n" % [
			_escape(str(item.get("title", "未命名证据"))),
			_escape(str(item.get("source", "来源未明"))),
			_escape(str(item.get("text", ""))),
		]
	return result


func _contradictions_text(snapshot: Dictionary) -> String:
	var dossier: Dictionary = _dict(snapshot.get("dossier", {}))
	var result := "[color=#8e8773]把来客的说法与旧档案对照。灰色项目需要继续追问。[/color]\n\n"
	var index := 0
	for raw: Variant in _array(dossier.get("contradictions", [])):
		var item := raw as Dictionary
		index += 1
		var unlocked := bool(item.get("unlocked", false))
		result += "[color=#d5aa5c][b]%02d / 来客说法[/b][/color]\n%s\n" % [index, _escape(str(item.get("statement", "无口供")))]
		if unlocked:
			result += "[color=#8eb9a0][b]✓ 已交叉核验[/b][/color]\n%s\n\n" % _escape(str(item.get("record", "记录缺失")))
		else:
			result += "[color=#77715f]□ 尚未核验：围绕此说法继续追问[/color]\n[color=#5f5b4d]档案记录已遮盖[/color]\n\n"
	if index == 0:
		result += "暂无可比对口供。"
	return result


func _dialogue_text(snapshot: Dictionary) -> String:
	var result := ""
	var transcript := _array(snapshot.get("transcript", []))
	var first := maxi(0, transcript.size() - 4)
	for index: int in range(first, transcript.size()):
		var line := transcript[index] as Dictionary
		var player := str(line.get("kind", "")) == "player"
		var color := "#8eb9a0" if player else "#d5aa5c"
		var speaker := "你" if player else str(line.get("speaker", "来客"))
		result += "[color=%s][b]%s[/b][/color]  %s\n" % [color, _escape(speaker), _escape(str(line.get("text", "")))]
	return result


func _configure_clause_selectors(snapshot: Dictionary) -> void:
	var slots: Dictionary = _dict(snapshot.get("clause_slots", {}))
	var selected: Dictionary = _dict(snapshot.get("selected_clauses", {}))
	_updating = true
	for slot: String in ["scope", "price", "exit"]:
		var selector := _clause_selectors.get(slot) as OptionButton
		var slot_data: Dictionary = _dict(slots.get(slot, {}))
		selector.clear()
		selector.add_item("— 留白 —")
		selector.set_item_metadata(0, "")
		var chosen_index := 0
		var options := _array(slot_data.get("options", []))
		for index: int in range(options.size()):
			var option := options[index] as Dictionary
			selector.add_item(str(option.get("label", "")))
			selector.set_item_metadata(index + 1, str(option.get("id", "")))
			if str(option.get("id", "")) == str(selected.get(slot, "")):
				chosen_index = index + 1
		selector.select(chosen_index)
		var detail := _clause_details.get(slot) as Label
		detail.text = "此处留白，契约不会生效。" if chosen_index == 0 else str((options[chosen_index - 1] as Dictionary).get("description", ""))
	_updating = false


func _render_contract_status(snapshot: Dictionary) -> void:
	if bool(snapshot.get("contract_accepted", false)):
		_contract_status.text = "[color=#8eb9a0][b]● 对方已经接受[/b][/color]\n落印后现实立即执行，不能修改。"
	elif bool(snapshot.get("contract_complete", false)):
		_contract_status.text = "[color=#d5aa5c][b]● 草案完整，尚未同意[/b][/color]\n递出草案，观察对方是否愿受这些字句约束。"
	else:
		_contract_status.text = "[color=#aaa187][b]○ 文书尚有空白[/b][/color]\n准入范围、交换代价、离开条件缺一不可。"


func _render_prompts(snapshot: Dictionary) -> void:
	for child: Node in _prompt_row.get_children():
		child.queue_free()
	var prompts := _array(snapshot.get("quick_prompts", []))
	for index: int in range(mini(prompts.size(), 3)):
		var prompt_text := str(prompts[index])
		var button := Button.new()
		button.text = _prompt_label(prompt_text, index)
		button.tooltip_text = prompt_text
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_fill_prompt.bind(prompt_text))
		_prompt_row.add_child(button)


func _prompt_label(text: String, index: int) -> String:
	if text.contains("身份") or text.contains("你是谁") or text.contains("名字"):
		return "核验身份"
	if text.contains("理解") or text.contains("相信") or text.contains("帮你") or text.contains("慢慢"):
		return "表示理解"
	if text.contains("代价") or text.contains("报酬") or text.contains("地契") or text.contains("秘密"):
		return "追问代价"
	if text.contains("范围") or text.contains("进入") or text.contains("位置") or text.contains("房间"):
		return "限定范围"
	if text.contains("离开") or text.contains("期限") or text.contains("完成") or text.contains("什么时候"):
		return "确认期限"
	if text.contains("证明") or text.contains("传感器") or text.contains("热成像"):
		return "要求证据"
	return "追问 %d" % (index + 1)


func _fill_prompt(text: String) -> void:
	_input.text = text
	_input.caret_column = text.length()
	focus_input()


func _submit() -> void:
	var text := _input.text.strip_edges()
	if text.is_empty():
		return
	_input.clear()
	player_submitted.emit(text)


func _on_case_selected(index: int) -> void:
	if _updating:
		return
	var case_id := str(_case_selector.get_item_metadata(index))
	if not case_id.is_empty() and case_id != _current_case_id:
		case_selected.emit(case_id)


func _on_clause_selected(index: int, slot: String) -> void:
	if _updating:
		return
	var selector := _clause_selectors.get(slot) as OptionButton
	var clause_id := str(selector.get_item_metadata(index))
	if not clause_id.is_empty():
		clause_selected.emit(slot, clause_id)


func _on_outcome_confirmed() -> void:
	if str(_snapshot.get("outcome", "")) != "failure":
		next_case_requested.emit()


func _set_bar(bar: ProgressBar, value_label: Label, value: int, color: Color) -> void:
	bar.value = clampi(value, 0, 100)
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		fill.bg_color = color
	if value_label != null:
		value_label.text = "%d" % value


func _inline_meter(label_text: String, color: Color, with_value: bool) -> Dictionary:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 62
	box.add_theme_constant_override("separation", 1)
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", MUTED)
	label.add_theme_font_size_override("font_size", 9)
	box.add_child(label)
	var row := HBoxContainer.new()
	box.add_child(row)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(46, 7)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var background := StyleBoxFlat.new()
	background.bg_color = Color("29291f")
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	var value: Label = null
	if with_value:
		value = Label.new()
		value.text = "100"
		value.custom_minimum_size.x = 23
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_font_size_override("font_size", 8)
		row.add_child(value)
	return {"root": box, "bar": bar, "value": value}


func _panel(color: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.shadow_color = Color("00000099")
	style.shadow_size = 9
	style.shadow_offset = Vector2(2, 4)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _place(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_right = 1.0
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom


func _margin(horizontal: int, vertical: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_bottom", vertical)
	return margin


func _header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", AMBER)
	label.add_theme_font_size_override("font_size", 11)
	return label


func _make_theme() -> Theme:
	var result := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Noto Sans CJK SC", "Noto Serif CJK SC", "SimSun"])
	font.font_weight = 500
	result.default_font = font
	result.default_font_size = 12
	result.set_color("font_color", "Label", INK)
	result.set_color("font_color", "Button", INK)
	result.set_color("font_color", "LineEdit", INK)
	result.set_color("font_color", "OptionButton", INK)
	result.set_color("default_color", "RichTextLabel", INK)
	var button := StyleBoxFlat.new()
	button.bg_color = Color("252216ee")
	button.border_color = Color("666047")
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		button.set_border_width(side, 1)
	button.set_content_margin_all(6)
	result.set_stylebox("normal", "Button", button)
	result.set_stylebox("normal", "OptionButton", button)
	var hover := button.duplicate() as StyleBoxFlat
	hover.bg_color = Color("38321d")
	hover.border_color = AMBER
	result.set_stylebox("hover", "Button", hover)
	result.set_stylebox("pressed", "Button", hover)
	result.set_stylebox("hover", "OptionButton", hover)
	result.set_stylebox("pressed", "OptionButton", hover)
	var disabled := button.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("161610bb")
	disabled.border_color = Color("3e3c31")
	result.set_stylebox("disabled", "Button", disabled)
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color("060806f2")
	input_style.border_color = Color("777054")
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		input_style.set_border_width(side, 1)
	input_style.set_content_margin_all(8)
	result.set_stylebox("normal", "LineEdit", input_style)
	var focus := input_style.duplicate() as StyleBoxFlat
	focus.border_color = AMBER
	result.set_stylebox("focus", "LineEdit", focus)
	return result


func _make_analog_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
		shader_type canvas_item;

		float hash(vec2 p) {
			return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
		}

		void fragment() {
			vec2 uv = UV;
			float edge = smoothstep(0.34, 0.72, distance(uv, vec2(0.5)));
			float scan = step(0.92, fract(uv.y * 360.0)) * 0.025;
			float grain = (hash(floor(uv * vec2(640.0, 360.0)) + floor(TIME * 12.0)) - 0.5) * 0.035;
			float dirty = smoothstep(0.84, 1.0, hash(floor(uv * vec2(24.0, 14.0)))) * 0.035;
			float alpha = clamp(edge * 0.62 + scan + grain + dirty, 0.0, 0.68);
			COLOR = vec4(vec3(0.008, 0.009, 0.006), alpha);
		}
	"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _escape(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return value as Array if value is Array else []
