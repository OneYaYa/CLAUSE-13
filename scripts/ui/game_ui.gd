class_name Clause13UI
extends Control


signal player_submitted(text: String)
signal clause_selected(slot: String, clause_id: String)
signal propose_requested()
signal verdict_requested(suspect_is_impostor: bool)
signal restart_requested()
signal next_case_requested()

const ENCOUNTER_TEXTURES := {
	"training_inspector": preload("res://assets/encounters/training_inspector_v1.png"),
	"rain_guest": preload("res://assets/encounters/rain_guest_v1.png"),
	"shadow_tailor": preload("res://assets/encounters/shadow_tailor_v1.png"),
	"red_rescue": preload("res://assets/encounters/red_rescue_v1.png"),
}
const INK := Color("edf1f2")
const MUTED := Color("9aa7ad")
const PAPER := Color("101619f2")
const PAPER_LIGHT := Color("11181cf5")
const BLACK_GLASS := Color("090e11f2")
const LINE := Color("3b4950")
const JADE := Color("79b99f")
const AMBER := Color("e0b367")
const RED := Color("d2665d")

var suppress_intro := false
var _snapshot: Dictionary = {}
var _catalog: Array[Dictionary] = []
var _updating := false
var _current_case_id := ""
var _elapsed := 0.0

var _encounter_background: TextureRect
var _scene_tint: ColorRect
var _flicker: ColorRect
var _scene_fade: ColorRect
var _overlay: ColorRect
var _dossier_panel: PanelContainer
var _contract_panel: PanelContainer
var _progress_label: Label
var _case_title: Label
var _turn_label: Label
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
var _trusted_button: Button
var _impostor_button: Button
var _status: Label
var _authority: Label
var _outcome_dialog: AcceptDialog
var _intro_dialog: AcceptDialog
var _auto_advance_timer: Timer
var _outcome_action := "none"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _make_theme()
	_build()
	set_process(true)
	set_process_unhandled_key_input(true)


func configure_cases(catalog: Array[Dictionary], current_case_id: String) -> void:
	_catalog = []
	for item: Dictionary in catalog:
		_catalog.append(item.duplicate(true))
	_current_case_id = current_case_id
	var current: Dictionary = {}
	for index: int in range(_catalog.size()):
		var item := _catalog[index]
		if str(item.get("id", "")) == current_case_id:
			current = item
			break
	if bool(current.get("is_tutorial", false)):
		_progress_label.text = "教学关"
	else:
		_progress_label.text = "案件 %d / 3" % int(current.get("number", 1))


func render(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	var next_case_id := str(snapshot.get("case_id", _current_case_id))
	if next_case_id != _current_case_id or _encounter_background.texture == null:
		_set_encounter(next_case_id)
	_current_case_id = next_case_id
	_case_title.text = "%s\n%s" % [str(snapshot.get("case_title", "未命名案件")), str(snapshot.get("case_subtitle", ""))]
	_turn_label.text = "核验 %d / %d" % [int(snapshot.get("turn", 0)), int(snapshot.get("max_turns", 0))]
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
	_trusted_button.disabled = terminal
	_impostor_button.disabled = terminal
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
	var correct := bool(debrief.get("correct", false))
	_outcome_dialog.title = str(debrief.get("title", "身份核验结束"))
	_outcome_dialog.dialog_text = "你的判断：%s\n实际身份：%s\n\n%s\n\n验证协议：%s" % [
		str(debrief.get("guess_label", "--")),
		str(debrief.get("actual_label", "--")),
		str(debrief.get("body", "核验结束。")),
		str(debrief.get("protocol_summary", "未使用")),
	]
	if correct:
		_outcome_action = "next"
		_outcome_dialog.ok_button_text = "立即继续"
		_outcome_dialog.dialog_text += "\n\n判断正确，2 秒后自动进入下一关。"
		_auto_advance_timer.start()
	else:
		_outcome_action = "retry"
		_outcome_dialog.ok_button_text = "重新审问"
	_outcome_dialog.popup_centered(Vector2i(540, 360))


func show_campaign_complete() -> void:
	_auto_advance_timer.stop()
	_outcome_action = "none"
	_outcome_dialog.title = "夜班完成"
	_outcome_dialog.dialog_text = "教学关与三宗正式案件已经全部完成。\n\n你学会了区分“物种异常”和“身份欺骗”：合法登记的异类不一定是伪人，看似普通的人也不能只凭外貌放行。"
	_outcome_dialog.ok_button_text = "关闭"
	_outcome_dialog.popup_centered(Vector2i(520, 300))


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
			target = (mouse / viewport_size - Vector2(0.5, 0.5)) * Vector2(4.0, 2.0)
		_encounter_background.position = Vector2(-30.0, -26.0) - target


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
	var panel := _panel(Color("0a1013f2"), LINE)
	_place(panel, 16.0, 16.0, -16.0, 72.0)
	add_child(panel)
	var margin := _margin(12, 7)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var mark := Label.new()
	mark.text = "CLAUSE 13\n夜间核验局"
	mark.add_theme_color_override("font_color", AMBER)
	mark.add_theme_font_size_override("font_size", 13)
	row.add_child(mark)
	_progress_label = Label.new()
	_progress_label.text = "教学关"
	_progress_label.custom_minimum_size.x = 72
	_progress_label.add_theme_color_override("font_color", JADE)
	_progress_label.add_theme_font_size_override("font_size", 12)
	row.add_child(_progress_label)
	_case_title = Label.new()
	_case_title.text = "等待接通\n未登记访客"
	_case_title.custom_minimum_size.x = 260
	_case_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_case_title.add_theme_font_size_override("font_size", 13)
	_case_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_case_title)
	_turn_label = Label.new()
	_turn_label.text = "核验 0 / 0"
	_turn_label.add_theme_color_override("font_color", INK)
	_turn_label.add_theme_font_size_override("font_size", 12)
	row.add_child(_turn_label)
	var dossier_toggle := Button.new()
	dossier_toggle.text = "卷宗"
	dossier_toggle.tooltip_text = "显示或收起案卷"
	dossier_toggle.pressed.connect(_toggle_dossier)
	row.add_child(dossier_toggle)
	var contract_toggle := Button.new()
	contract_toggle.text = "验证协议"
	contract_toggle.tooltip_text = "显示或收起可选的口供验证工具"
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
	classified.text = "只读档案"
	classified.add_theme_color_override("font_color", MUTED)
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
	heading.add_child(_header("验证协议 / PROTOCOL"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(spacer)
	var clause := Label.new()
	clause.text = "可选"
	clause.add_theme_color_override("font_color", JADE)
	clause.add_theme_font_size_override("font_size", 11)
	heading.add_child(clause)
	var explain := Label.new()
	explain.text = "用途：把口供变成 3 个可检查条件。\n协议只提供线索，不决定胜负。"
	explain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explain.add_theme_color_override("font_color", MUTED)
	explain.add_theme_font_size_override("font_size", 11)
	box.add_child(explain)
	var slot_names := {"scope": "1  范围", "price": "2  代价 / 信息", "exit": "3  离场信号"}
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
	_contract_status.custom_minimum_size.y = 52
	_contract_status.fit_content = false
	box.add_child(_contract_status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	_propose_button = Button.new()
	_propose_button.text = "发起验证"
	_propose_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_propose_button.pressed.connect(propose_requested.emit)
	buttons.add_child(_propose_button)
	box.add_child(HSeparator.new())
	var verdict_header := _header("最终判断 / VERDICT")
	box.add_child(verdict_header)
	var verdict_help := Label.new()
	verdict_help.text = "胜负只看这里：身份与来意能否被交叉验证？"
	verdict_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	verdict_help.add_theme_color_override("font_color", MUTED)
	verdict_help.add_theme_font_size_override("font_size", 10)
	box.add_child(verdict_help)
	var verdict_buttons := HBoxContainer.new()
	verdict_buttons.add_theme_constant_override("separation", 8)
	box.add_child(verdict_buttons)
	_trusted_button = Button.new()
	_trusted_button.text = "可信来客"
	_trusted_button.tooltip_text = "身份、来意和记录能够互相印证"
	_trusted_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trusted_button.add_theme_color_override("font_color", JADE)
	_trusted_button.pressed.connect(verdict_requested.emit.bind(false))
	verdict_buttons.add_child(_trusted_button)
	_impostor_button = Button.new()
	_impostor_button.text = "伪人 / 冒名者"
	_impostor_button.tooltip_text = "身份或来意由模仿、冒用和欺骗构成"
	_impostor_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_impostor_button.add_theme_color_override("font_color", RED)
	_impostor_button.pressed.connect(verdict_requested.emit.bind(true))
	verdict_buttons.add_child(_impostor_button)
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
	_auto_advance_timer = Timer.new()
	_auto_advance_timer.one_shot = true
	_auto_advance_timer.wait_time = 2.0
	_auto_advance_timer.timeout.connect(_on_auto_advance)
	add_child(_auto_advance_timer)
	_intro_dialog = AcceptDialog.new()
	_intro_dialog.title = ""
	add_child(_intro_dialog)


func _show_intro() -> void:
	_intro_dialog.popup_centered(Vector2i(540, 330))


func _set_encounter(case_id: String) -> void:
	_encounter_background.texture = ENCOUNTER_TEXTURES.get(case_id, ENCOUNTER_TEXTURES["rain_guest"])
	match case_id:
		"training_inspector":
			_scene_tint.color = Color("0710150b")
		"shadow_tailor":
			_scene_tint.color = Color("080b1014")
		"red_rescue":
			_scene_tint.color = Color("1e080612")
		_:
			_scene_tint.color = Color("07120c12")
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
	var result := "[color=#e0b367][font_size=16][b]%s[/b][/font_size][/color]\n" % _escape(str(dossier.get("record_name", npc.get("name", "身份不明"))))
	result += "[color=#9aa7ad]档案编号[/color]  %s\n" % _escape(str(dossier.get("archive_id", "未建档")))
	result += "[color=#9aa7ad]已知别名[/color]  %s\n" % _escape(" / ".join(aliases))
	result += "[color=#9aa7ad]异常分类[/color]  %s\n" % _escape(str(dossier.get("classification", npc.get("kind", "待核验"))))
	result += "[color=#9aa7ad]登记状态[/color]  %s\n" % _escape(str(dossier.get("registry_status", "记录缺失")))
	result += "[color=#9aa7ad]上次出现[/color]  %s\n\n" % _escape(str(dossier.get("last_seen", "无记录")))
	result += "[color=#d2665d][b]风险标签[/b][/color]\n"
	for raw: Variant in _array(dossier.get("risk_flags", [])):
		result += "[color=#df7a70]■[/color] %s　" % _escape(str(raw))
	result += "\n\n[color=#e0b367][b]已知行为[/b][/color]"
	for raw: Variant in _array(dossier.get("known_behavior", [])):
		result += "\n[color=#79b99f]—[/color] %s" % _escape(str(raw))
	result += "\n\n[color=#e0b367][b]建议问法[/b][/color]"
	for raw: Variant in _array(dossier.get("interview_leads", [])):
		result += "\n[color=#79b99f]›[/color] %s" % _escape(str(raw))
	result += "\n\n[color=#e0b367][b]本夜目标[/b][/color]\n%s\n[color=#9aa7ad]预计 %d 分钟[/color]" % [
		_escape(str(snapshot.get("objective", ""))), int(snapshot.get("estimated_minutes", 0))
	]
	return result


func _evidence_text(snapshot: Dictionary) -> String:
	var result := "[color=#9aa7ad]只记录可交叉验证的事实；新口供会自动归档。[/color]\n\n"
	for raw: Variant in _array(snapshot.get("evidence", [])):
		var item := raw as Dictionary
		result += "[color=#e0b367][b]%s[/b][/color]\n[color=#9aa7ad]%s[/color]\n%s\n\n" % [
			_escape(str(item.get("title", "未命名证据"))),
			_escape(str(item.get("source", "来源未明"))),
			_escape(str(item.get("text", ""))),
		]
	return result


func _contradictions_text(snapshot: Dictionary) -> String:
	var dossier: Dictionary = _dict(snapshot.get("dossier", {}))
	var result := "[color=#9aa7ad]把来客说法与旧档案对照；未核验项目需要继续追问。[/color]\n\n"
	var index := 0
	for raw: Variant in _array(dossier.get("contradictions", [])):
		var item := raw as Dictionary
		index += 1
		var unlocked := bool(item.get("unlocked", false))
		result += "[color=#e0b367][b]%02d / 来客说法[/b][/color]\n%s\n" % [index, _escape(str(item.get("statement", "无口供")))]
		if unlocked:
			result += "[color=#79b99f][b]✓ 已交叉核验[/b][/color]\n%s\n\n" % _escape(str(item.get("record", "记录缺失")))
		else:
			result += "[color=#7f8a8f]□ 尚未核验：围绕此说法继续追问[/color]\n[color=#59656a]档案记录已遮盖[/color]\n\n"
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
		var color := "#79b99f" if player else "#e0b367"
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
		selector.add_item("— 未选择 —")
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
		detail.text = "选择一个能被现场证据检查的条件。" if chosen_index == 0 else str((options[chosen_index - 1] as Dictionary).get("description", ""))
	_updating = false


func _render_contract_status(snapshot: Dictionary) -> void:
	if bool(snapshot.get("protocol_tested", false)):
		var color := "#79b99f" if bool(snapshot.get("contract_accepted", false)) else "#e0b367"
		_contract_status.text = "[color=%s][b]验证结果[/b][/color]\n%s" % [color, _escape(str(snapshot.get("protocol_summary", "核验完成。")))]
	elif bool(snapshot.get("contract_complete", false)):
		_contract_status.text = "[color=#e0b367][b]条件填写完成[/b][/color]\n发起验证，观察口供是否经得起客观限制。"
	else:
		_contract_status.text = "[color=#9aa7ad][b]协议尚未填写[/b][/color]\n这是可选工具；你也可以根据已有证据直接判断。"


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
	if text.contains("工号") or text.contains("路线") or text.contains("徽章"):
		return "核对工号"
	if text.contains("协议") or text.contains("条约") or text.contains("验证"):
		return "协议用途"
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


func _on_clause_selected(index: int, slot: String) -> void:
	if _updating:
		return
	var selector := _clause_selectors.get(slot) as OptionButton
	var clause_id := str(selector.get_item_metadata(index))
	if not clause_id.is_empty():
		clause_selected.emit(slot, clause_id)


func _on_outcome_confirmed() -> void:
	_auto_advance_timer.stop()
	match _outcome_action:
		"next":
			next_case_requested.emit()
		"retry":
			restart_requested.emit()
	_outcome_action = "none"


func _on_auto_advance() -> void:
	if _outcome_action != "next":
		return
	_outcome_dialog.hide()
	_outcome_action = "none"
	next_case_requested.emit()


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
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
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
	button.bg_color = Color("172126ee")
	button.border_color = LINE
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		button.set_border_width(side, 1)
	button.set_content_margin_all(6)
	result.set_stylebox("normal", "Button", button)
	result.set_stylebox("normal", "OptionButton", button)
	var hover := button.duplicate() as StyleBoxFlat
	hover.bg_color = Color("223139")
	hover.border_color = AMBER
	result.set_stylebox("hover", "Button", hover)
	result.set_stylebox("pressed", "Button", hover)
	result.set_stylebox("hover", "OptionButton", hover)
	result.set_stylebox("pressed", "OptionButton", hover)
	var disabled := button.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("101619bb")
	disabled.border_color = Color("2c373c")
	result.set_stylebox("disabled", "Button", disabled)
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color("071014f5")
	input_style.border_color = LINE
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
		void fragment() {
			vec2 uv = UV;
			float edge = smoothstep(0.36, 0.74, distance(uv, vec2(0.5)));
			float alpha = clamp(edge * 0.38, 0.0, 0.42);
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
