class_name Clause13CaseSimulation
extends RefCounted


signal state_changed(snapshot: Dictionary)
signal case_event(event: Dictionary)
signal case_ended(outcome: String, snapshot: Dictionary)

const DEFAULT_CAMPAIGN_PATH := "res://data/campaign.json"
const LocalAgent := preload("res://scripts/services/local_npc_agent.gd")
const CLAUSE_SLOTS: Array[String] = ["scope", "price", "exit"]

var _campaign_path := DEFAULT_CAMPAIGN_PATH
var _campaign: Dictionary = {}
var _case_by_id: Dictionary = {}
var _case: Dictionary = {}
var _state: Dictionary = {}
var _load_error := ""
var _agent: LocalNpcAgent


func _init(campaign_path: String = DEFAULT_CAMPAIGN_PATH) -> void:
	_campaign_path = campaign_path
	_agent = LocalAgent.new() as LocalNpcAgent
	_load_campaign()


func case_catalog() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for raw: Variant in _campaign.get("cases", []) as Array:
		var configured := raw as Dictionary
		output.append({
			"id": str(configured.get("id", "")),
			"number": int(configured.get("number", output.size() + 1)),
			"title": str(configured.get("title", "未命名案件")),
			"subtitle": str(configured.get("subtitle", "")),
			"estimated_minutes": int(configured.get("estimated_minutes", 8)),
		})
	return output


func start_case(case_id: String) -> Dictionary:
	if not _case_by_id.has(case_id):
		return {"ok": false, "error": "案件不存在：%s" % case_id, "is_terminal": true}
	_case = (_case_by_id[case_id] as Dictionary).duplicate(true)
	var npc: Dictionary = _case.get("npc", {}) as Dictionary
	var starting_social: Dictionary = _case.get("starting_social", {}) as Dictionary
	var evidence: Array[Dictionary] = []
	for raw: Variant in _case.get("starting_evidence", []) as Array:
		evidence.append((raw as Dictionary).duplicate(true))
	_state = {
		"case_id": case_id,
		"turn": 0,
		"ward": int(_case.get("starting_ward", 100)),
		"trust": int(starting_social.get("trust", 45)),
		"pressure": int(starting_social.get("pressure", 35)),
		"revealed_fact_ids": [],
		"evidence": evidence,
		"selected_clauses": {"scope": "", "price": "", "exit": ""},
		"contract_accepted": false,
		"transcript": [{
			"speaker": str(npc.get("name", "来客")),
			"text": str(npc.get("intro", "……公证员，你听得见吗？")),
			"kind": "npc",
		}],
		"memory": {
			"topics": [],
			"promises": [],
			"player_name": "",
			"last_player_line": "",
		},
		"outcome": "ongoing",
		"ending_reason": "",
		"is_terminal": false,
		"debrief": {},
		"last_event": {},
	}
	var view := snapshot()
	state_changed.emit(view)
	return view


func restart() -> Dictionary:
	if _case.is_empty():
		var catalog := case_catalog()
		if catalog.is_empty():
			return snapshot()
		return start_case(str(catalog[0].get("id", "")))
	return start_case(str(_case.get("id", "")))


func snapshot() -> Dictionary:
	if _state.is_empty():
		return {"ok": false, "error": _load_error, "is_terminal": true, "outcome": "failure"}
	var npc: Dictionary = _case.get("npc", {}) as Dictionary
	var selected: Dictionary = _state.get("selected_clauses", {}) as Dictionary
	return {
		"ok": true,
		"campaign_title": str(_campaign.get("title", "CLAUSE 13")),
		"case_id": str(_case.get("id", "")),
		"case_number": int(_case.get("number", 0)),
		"case_total": (_campaign.get("cases", []) as Array).size(),
		"case_title": str(_case.get("title", "")),
		"case_subtitle": str(_case.get("subtitle", "")),
		"estimated_minutes": int(_case.get("estimated_minutes", 8)),
		"objective": str(_case.get("objective", "")),
		"briefing": (_case.get("briefing", []) as Array).duplicate(true),
		"dossier": _public_dossier(),
		"npc": {
			"name": str(npc.get("name", "来客")),
			"kind": str(npc.get("kind", "未登记异类")),
			"claim": str(npc.get("claim", "身份待核验")),
			"mood": _mood(),
		},
		"turn": int(_state.get("turn", 0)),
		"max_turns": int(_case.get("max_turns", 10)),
		"ward": int(_state.get("ward", 0)),
		"trust": int(_state.get("trust", 0)),
		"pressure": int(_state.get("pressure", 0)),
		"evidence": (_state.get("evidence", []) as Array).duplicate(true),
		"revealed_fact_ids": (_state.get("revealed_fact_ids", []) as Array).duplicate(),
		"clause_slots": _public_clause_slots(),
		"selected_clauses": selected.duplicate(true),
		"selected_clause_labels": _selected_clause_labels(selected),
		"contract_complete": _contract_complete(selected),
		"contract_accepted": bool(_state.get("contract_accepted", false)),
		"transcript": (_state.get("transcript", []) as Array).duplicate(true),
		"memory": (_state.get("memory", {}) as Dictionary).duplicate(true),
		"quick_prompts": (_case.get("quick_prompts", []) as Array).duplicate(true),
		"guidance": _guidance(),
		"outcome": str(_state.get("outcome", "ongoing")),
		"ending_reason": str(_state.get("ending_reason", "")),
		"is_terminal": bool(_state.get("is_terminal", false)),
		"debrief": (_state.get("debrief", {}) as Dictionary).duplicate(true),
		"last_event": (_state.get("last_event", {}) as Dictionary).duplicate(true),
	}


func talk(player_text: String) -> Dictionary:
	return talk_with_reply(player_text, "")


func dialogue_context(player_text: String) -> Dictionary:
	var clean := player_text.strip_edges()
	if clean.is_empty() or not _can_act():
		return {}
	var local_decision: Dictionary = _agent.decide({
		"case": _case.duplicate(true),
		"state": _state.duplicate(true),
	}, clean)
	var npc: Dictionary = _case.get("npc", {}) as Dictionary
	var revealed_facts: Array[Dictionary] = []
	for raw: Variant in _case.get("facts", []) as Array:
		var fact := raw as Dictionary
		if str(fact.get("id", "")) in (_state.get("revealed_fact_ids", []) as Array) or str(fact.get("id", "")) == str(local_decision.get("reveal_id", "")):
			revealed_facts.append({
				"id": str(fact.get("id", "")),
				"evidence": str(fact.get("evidence", "")),
				"private_reply_fact": str(fact.get("reply", "")),
			})
	return {
		"case_id": str(_case.get("id", "")),
		"case_title": str(_case.get("title", "")),
		"objective": str(_case.get("objective", "")),
		"public_dossier": _public_dossier(),
		"npc": {
			"name": str(npc.get("name", "来客")),
			"kind": str(npc.get("kind", "未登记异类")),
			"claim": str(npc.get("claim", "")),
			"persona": str(npc.get("persona", npc.get("claim", ""))),
			"voice_examples": (npc.get("responses", {}) as Dictionary).duplicate(true),
		},
		"state": {
			"trust": int(_state.get("trust", 0)),
			"pressure": int(_state.get("pressure", 0)),
			"mood": _mood(),
			"turn": int(_state.get("turn", 0)),
			"memory": (_state.get("memory", {}) as Dictionary).duplicate(true),
		},
		"authoritative_read": {
			"intent": str(local_decision.get("intent", "conversation")),
			"topic": str(local_decision.get("topic", "general")),
			"reveal_id": str(local_decision.get("reveal_id", "")),
			"required_fact": str(local_decision.get("reply", "")) if not str(local_decision.get("reveal_id", "")).is_empty() else "",
		},
		"known_facts": revealed_facts,
		"transcript": (_state.get("transcript", []) as Array).slice(maxi(0, (_state.get("transcript", []) as Array).size() - 8)),
	}


func talk_with_reply(player_text: String, reply_override: String = "") -> Dictionary:
	var clean := player_text.strip_edges()
	if clean.is_empty():
		return _result(false, "请先输入要对来客说的话。")
	if not _can_act():
		return _result(false, "本案已经封存。")
	var context := {
		"case": _case.duplicate(true),
		"state": _state.duplicate(true),
	}
	var decision: Dictionary = _agent.decide(context, clean)
	var online_reply := reply_override.strip_edges().left(600)
	if not online_reply.is_empty():
		decision["reply"] = online_reply
	_advance_turn(4)
	_state["trust"] = clampi(int(_state.get("trust", 0)) + int(decision.get("trust_delta", 0)), 0, 100)
	_state["pressure"] = clampi(int(_state.get("pressure", 0)) + int(decision.get("pressure_delta", 0)), 0, 100)
	_remember_player_line(clean, decision)
	var reveal_id := str(decision.get("reveal_id", ""))
	if not reveal_id.is_empty():
		_reveal_fact(reveal_id)
	var npc_name := str((_case.get("npc", {}) as Dictionary).get("name", "来客"))
	_append_transcript("你", clean, "player")
	_append_transcript(npc_name, str(decision.get("reply", "……")), "npc")
	var event := {
		"type": "dialogue",
		"text": str(decision.get("reply", "……")),
		"intent": str(decision.get("intent", "conversation")),
		"topic": str(decision.get("topic", "general")),
		"reveal_id": reveal_id,
	}
	return _commit_event(event)


func select_clause(slot: String, clause_id: String) -> Dictionary:
	if not _can_act():
		return _result(false, "本案已经封存。")
	if slot not in CLAUSE_SLOTS or not _clause_option(slot, clause_id).has("id"):
		return _result(false, "无效条款：%s/%s" % [slot, clause_id])
	var selected: Dictionary = _state.get("selected_clauses", {}) as Dictionary
	selected[slot] = clause_id
	_state["selected_clauses"] = selected
	_state["contract_accepted"] = false
	var event := {"type": "clause", "text": "%s已写入草案。" % str(_clause_option(slot, clause_id).get("label", clause_id))}
	return _commit_event(event, false)


func propose_contract() -> Dictionary:
	if not _can_act():
		return _result(false, "本案已经封存。")
	var selected: Dictionary = _state.get("selected_clauses", {}) as Dictionary
	if not _contract_complete(selected):
		return _result(false, "契约还缺少条款：进入范围、交换代价和离开条件必须全部填写。")
	_advance_turn(5)
	var acceptance: Dictionary = _case.get("acceptance", {}) as Dictionary
	var score := 0
	for slot: String in CLAUSE_SLOTS:
		score += int(_clause_option(slot, str(selected.get(slot, ""))).get("npc_score", 0))
	var trust := int(_state.get("trust", 0))
	score += floori(float(trust - 40) / 5.0)
	var accepted := trust >= int(acceptance.get("min_trust", 35)) and score >= int(acceptance.get("threshold", 3))
	_state["contract_accepted"] = accepted
	var npc: Dictionary = _case.get("npc", {}) as Dictionary
	var reply := str(acceptance.get("accepted_reply", "这些字句，我接受。可以签了。")) if accepted else str(acceptance.get("rejected_reply", "不。你给我的太少，限制却太多。重新谈。"))
	_append_transcript("你", "我提出这份三项契约。", "player")
	_append_transcript(str(npc.get("name", "来客")), reply, "npc")
	var event := {"type": "proposal", "text": reply, "accepted": accepted, "score": score}
	return _commit_event(event)


func sign_contract() -> Dictionary:
	if not _can_act():
		return _result(false, "本案已经封存。")
	if not bool(_state.get("contract_accepted", false)):
		return _result(false, "来客尚未接受当前草案；先提出条款并取得同意。")
	var selected: Dictionary = _state.get("selected_clauses", {}) as Dictionary
	var safe_contract: Dictionary = _case.get("safe_contract", {}) as Dictionary
	var forbidden: Array = _case.get("forbidden", []) as Array
	var breached := false
	for raw: Variant in forbidden:
		var rule := raw as Dictionary
		if str(selected.get(str(rule.get("slot", "")), "")) == str(rule.get("id", "")):
			breached = true
			break
	var exact_safe := true
	for slot: String in CLAUSE_SLOTS:
		if str(selected.get(slot, "")) != str(safe_contract.get(slot, "")):
			exact_safe = false
			break
	var outcome := "failure" if breached else "success" if exact_safe else "costly_success"
	var endings: Dictionary = _case.get("endings", {}) as Dictionary
	var ending: Dictionary = endings.get(outcome, {}) as Dictionary
	_state["outcome"] = outcome
	_state["ending_reason"] = "breach" if breached else "airtight_contract" if exact_safe else "loophole_contained"
	_state["is_terminal"] = true
	_state["debrief"] = {
		"title": str(ending.get("title", "案件封存")),
		"body": str(ending.get("body", "契约已执行。")),
		"grade": "S" if exact_safe else "B" if not breached else "F",
		"contract": _selected_clause_labels(selected),
		"trust": int(_state.get("trust", 0)),
		"turns": int(_state.get("turn", 0)),
	}
	var event := {"type": "ending", "text": str(ending.get("body", "契约已执行。")), "outcome": outcome}
	return _commit_event(event)


func _load_campaign() -> bool:
	_load_error = ""
	_case_by_id.clear()
	if not FileAccess.file_exists(_campaign_path):
		_load_error = "找不到战役数据：%s" % _campaign_path
		return false
	var file := FileAccess.open(_campaign_path, FileAccess.READ)
	if file == null:
		_load_error = "无法读取战役数据。"
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_load_error = "战役 JSON 无效。"
		return false
	_campaign = parsed as Dictionary
	if int(_campaign.get("schema_version", 0)) != 1:
		_load_error = "战役 schema_version 必须为 1。"
		return false
	for raw: Variant in _campaign.get("cases", []) as Array:
		if not raw is Dictionary:
			continue
		var configured := raw as Dictionary
		var case_id := str(configured.get("id", ""))
		if not case_id.is_empty():
			_case_by_id[case_id] = configured.duplicate(true)
	return not _case_by_id.is_empty()


func _advance_turn(ward_cost: int) -> void:
	_state["turn"] = int(_state.get("turn", 0)) + 1
	_state["ward"] = maxi(0, int(_state.get("ward", 0)) - ward_cost - int(_state.get("pressure", 0)) / 35)


func _commit_event(event: Dictionary, check_failure: bool = true) -> Dictionary:
	_state["last_event"] = event.duplicate(true)
	if check_failure and not bool(_state.get("is_terminal", false)):
		if int(_state.get("ward", 0)) <= 0 or int(_state.get("turn", 0)) >= int(_case.get("max_turns", 10)):
			_finish_failure("ward_broken" if int(_state.get("ward", 0)) <= 0 else "deadline")
	var view := snapshot()
	var result := _result(true, str(event.get("text", "")))
	result["event"] = event.duplicate(true)
	result["snapshot"] = view
	case_event.emit(event.duplicate(true))
	state_changed.emit(view)
	if bool(_state.get("is_terminal", false)):
		case_ended.emit(str(_state.get("outcome", "failure")), view)
	return result


func _finish_failure(reason: String) -> void:
	var endings: Dictionary = _case.get("endings", {}) as Dictionary
	var ending: Dictionary = endings.get("failure", {}) as Dictionary
	_state["outcome"] = "failure"
	_state["ending_reason"] = reason
	_state["is_terminal"] = true
	_state["debrief"] = {
		"title": str(ending.get("title", "封印失效")),
		"body": str(ending.get("body", "谈判时间耗尽，门槛封印失效。")),
		"grade": "F",
		"contract": _selected_clause_labels(_state.get("selected_clauses", {}) as Dictionary),
		"trust": int(_state.get("trust", 0)),
		"turns": int(_state.get("turn", 0)),
	}


func _remember_player_line(text: String, decision: Dictionary) -> void:
	var memory: Dictionary = _state.get("memory", {}) as Dictionary
	var topics: Array = memory.get("topics", []) as Array
	var topic := str(decision.get("topic", "general"))
	if topic not in topics:
		topics.append(topic)
	memory["topics"] = topics
	memory["last_player_line"] = text.left(180)
	if text.contains("我保证") or text.contains("我答应") or text.contains("我会"):
		var promises: Array = memory.get("promises", []) as Array
		promises.append(text.left(100))
		if promises.size() > 4:
			promises = promises.slice(promises.size() - 4)
		memory["promises"] = promises
	var regex := RegEx.new()
	if regex.compile("(?:我叫|叫我)([\\p{Han}A-Za-z0-9_·]{1,12})") == OK:
		var matched := regex.search(text)
		if matched != null:
			memory["player_name"] = matched.get_string(1)
	_state["memory"] = memory


func _reveal_fact(fact_id: String) -> void:
	var revealed: Array = _state.get("revealed_fact_ids", []) as Array
	if fact_id in revealed:
		return
	for raw: Variant in _case.get("facts", []) as Array:
		var fact := raw as Dictionary
		if str(fact.get("id", "")) != fact_id:
			continue
		revealed.append(fact_id)
		var evidence: Array = _state.get("evidence", []) as Array
		evidence.append({
			"id": fact_id,
			"title": str(fact.get("title", "新证据")),
			"text": str(fact.get("evidence", "")),
			"source": str(fact.get("source", "谈判记录")),
		})
		_state["evidence"] = evidence
		break
	_state["revealed_fact_ids"] = revealed


func _append_transcript(speaker: String, text: String, kind: String) -> void:
	var transcript: Array = _state.get("transcript", []) as Array
	transcript.append({"speaker": speaker, "text": text, "kind": kind})
	if transcript.size() > 32:
		transcript = transcript.slice(transcript.size() - 32)
	_state["transcript"] = transcript


func _public_clause_slots() -> Dictionary:
	var output: Dictionary = {}
	var configured: Dictionary = _case.get("clauses", {}) as Dictionary
	for slot: String in CLAUSE_SLOTS:
		var source: Dictionary = configured.get(slot, {}) as Dictionary
		var options: Array[Dictionary] = []
		for raw: Variant in source.get("options", []) as Array:
			var option := raw as Dictionary
			options.append({
				"id": str(option.get("id", "")),
				"label": str(option.get("label", "")),
				"description": str(option.get("description", "")),
			})
		output[slot] = {"label": str(source.get("label", slot)), "options": options}
	return output


func _public_dossier() -> Dictionary:
	var output := (_case.get("dossier", {}) as Dictionary).duplicate(true)
	var public_contradictions: Array[Dictionary] = []
	var revealed: Array = _state.get("revealed_fact_ids", []) as Array
	for raw: Variant in output.get("contradictions", []) as Array:
		var item := raw as Dictionary
		var fact_id := str(item.get("fact_id", ""))
		var unlocked := fact_id.is_empty() or fact_id in revealed
		public_contradictions.append({
			"statement": str(item.get("statement", "")),
			"record": str(item.get("record", "")) if unlocked else "",
			"unlocked": unlocked,
		})
	output["contradictions"] = public_contradictions
	return output


func _clause_option(slot: String, clause_id: String) -> Dictionary:
	var clauses: Dictionary = _case.get("clauses", {}) as Dictionary
	var configured: Dictionary = clauses.get(slot, {}) as Dictionary
	for raw: Variant in configured.get("options", []) as Array:
		var option := raw as Dictionary
		if str(option.get("id", "")) == clause_id:
			return option
	return {}


func _selected_clause_labels(selected: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	for slot: String in CLAUSE_SLOTS:
		var clause_id := str(selected.get(slot, ""))
		output[slot] = str(_clause_option(slot, clause_id).get("label", "未填写"))
	return output


func _contract_complete(selected: Dictionary) -> bool:
	for slot: String in CLAUSE_SLOTS:
		if str(selected.get(slot, "")).is_empty():
			return false
	return true


func _can_act() -> bool:
	return not _state.is_empty() and not bool(_state.get("is_terminal", false))


func _mood() -> String:
	var pressure := int(_state.get("pressure", 0))
	var trust := int(_state.get("trust", 0))
	if pressure >= 75:
		return "threatening"
	if trust >= 65:
		return "open"
	if trust < 30:
		return "guarded"
	return "watchful"


func _guidance() -> String:
	if bool(_state.get("is_terminal", false)):
		return "本案已经封存；可复盘或进入下一案。"
	var revealed: Array = _state.get("revealed_fact_ids", []) as Array
	var selected: Dictionary = _state.get("selected_clauses", {}) as Dictionary
	if revealed.size() < 2:
		return "先问身份、来意、规则或代价。来客只有在信任你时才会说出关键细节。"
	if not _contract_complete(selected):
		return "根据证据填写三项条款。最容易被接受的条件，往往不是最安全的条件。"
	if not bool(_state.get("contract_accepted", false)):
		return "提出草案。如果对方拒绝，继续谈判提升信任，或修改对它更有吸引力的条款。"
	return "来客已口头接受。签署后条款会立刻成为世界规则，无法撤回。"


func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message, "snapshot": snapshot()}
