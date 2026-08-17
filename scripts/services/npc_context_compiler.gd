class_name Clause13NpcContextCompiler
extends RefCounted


const MAX_DIALOGUE_LINES := 8
const MAX_MEMORIES := 6
const MAX_BELIEFS := 8


func compile(source: Dictionary) -> Dictionary:
	var npc: Dictionary = source.get("npc", {}) as Dictionary
	var state: Dictionary = source.get("state", {}) as Dictionary
	var authoritative: Dictionary = source.get("authoritative_read", {}) as Dictionary
	var case_id := str(source.get("case_id", "unknown_case"))
	var snapshot_version := int(state.get("state_version", 0))
	var mood := str(state.get("mood", "watchful"))
	var included_ids: Array[String] = []
	var dropped: Array[Dictionary] = []
	var beliefs := _compile_beliefs(
		source.get("facts", []) as Array,
		state.get("revealed_fact_ids", []) as Array,
		str(authoritative.get("reveal_id", "")),
		case_id,
		str(npc.get("claim", "")),
		included_ids,
		dropped
	)
	var memories := _compile_memories(state.get("memory", {}) as Dictionary, included_ids, dropped)
	var recent_dialogue := _compile_dialogue(source.get("transcript", []) as Array, dropped)
	var persona_core := _persona_core(npc)
	var active_mode := _scene_mode(npc, mood)
	var director := _director_intent(state, authoritative, beliefs.size())
	var current_scene := {
		"world_time": "夜间核验 / 第 %d 轮" % int(state.get("turn", 0)),
		"location": "门槛事务局核验窗口；来客仍在门外",
		"case_id": case_id,
		"case_title": str(source.get("case_title", "")),
		"task_stage": "verdict_due" if bool(state.get("talk_exhausted", false)) else "interview",
		"visible_state": {
			"protocol_tested": bool(state.get("protocol_tested", false)),
			"revealed_belief_ids": (state.get("revealed_fact_ids", []) as Array).duplicate(),
		},
	}
	var relationship := {
		"target": "player",
		"trust_band": _band(int(state.get("trust", 0))),
		"pressure_band": _band(int(state.get("pressure", 0))),
		"current_mood": mood,
		"recent_change": str(state.get("relationship_change", "stable")),
	}
	var semantic_anchor := str(authoritative.get("semantic_anchor", authoritative.get("required_fact", ""))).left(500)
	var output_contract := {
		"visible_fields": ["utterance", "action"],
		"audit_fields": ["referenced_ids", "proposed_actions"],
		"allowed_action_proposals": ["gesture", "request_clarification", "refuse"],
		"authority": "dialogue_only",
	}
	var sections := {
		"persona_core": persona_core,
		"active_scene_mode": active_mode,
		"current_scene": current_scene,
		"known_beliefs": beliefs,
		"relevant_memories": memories,
		"relationship_state": relationship,
		"director_intent": director,
		"recent_dialogue": recent_dialogue,
	}
	return {
		"context_schema_version": 2,
		"case_id": case_id,
		"turn_id": "%s:dialogue:v%d" % [case_id, snapshot_version],
		"snapshot_version": snapshot_version,
		"npc": {
			"name": str(npc.get("name", "来客")).left(40),
			"kind": str(npc.get("kind", "异类")).left(80),
			"claim": str(npc.get("claim", "")).left(160),
			"persona_core": persona_core,
			"active_scene_mode": active_mode,
		},
		"current_scene": current_scene,
		"known_beliefs": beliefs,
		"relevant_memories": memories,
		"relationship_state": relationship,
		"director_intent": director,
		"authoritative_read": {
			"intent": str(authoritative.get("intent", "conversation")),
			"topic": str(authoritative.get("topic", "general")),
			"reveal_id": str(authoritative.get("reveal_id", "")),
			"semantic_anchor": semantic_anchor,
		},
		"recent_dialogue": recent_dialogue,
		"output_contract": output_contract,
		"prompt_trace": {
			"snapshot_version": snapshot_version,
			"included_ids": included_ids,
			"dropped": dropped,
			"section_chars": _section_sizes(sections),
			"compiler_version": "clause13-context-v2",
		},
	}


func _compile_beliefs(
	facts: Array,
	revealed_ids: Array,
	current_reveal_id: String,
	case_id: String,
	claim: String,
	included_ids: Array[String],
	dropped: Array[Dictionary]
) -> Array[Dictionary]:
	var beliefs: Array[Dictionary] = []
	var claim_id := "belief:%s:claim" % case_id
	beliefs.append({
		"belief_id": claim_id,
		"content": claim.left(240),
		"confidence": 0.9,
		"source": "npc_self_report",
		"truth_status": "npc_claim",
	})
	included_ids.append(claim_id)
	for raw: Variant in facts:
		if beliefs.size() >= MAX_BELIEFS:
			break
		var fact := raw as Dictionary
		var fact_id := str(fact.get("id", ""))
		if fact_id.is_empty():
			continue
		if fact_id not in revealed_ids and fact_id != current_reveal_id:
			dropped.append({"id": fact_id, "reason": "knowledge_lock"})
			continue
		beliefs.append({
			"belief_id": fact_id,
			"content": str(fact.get("reply", "")).left(360),
			"confidence": 0.95,
			"source": "npc_experience",
			"truth_status": "npc_belief",
		})
		included_ids.append(fact_id)
	return beliefs


func _compile_memories(memory: Dictionary, included_ids: Array[String], dropped: Array[Dictionary]) -> Array[Dictionary]:
	var entries: Array = memory.get("entries", []) as Array
	var start := maxi(0, entries.size() - MAX_MEMORIES)
	var output: Array[Dictionary] = []
	for index: int in range(entries.size()):
		var item := entries[index] as Dictionary
		var memory_id := str(item.get("memory_id", ""))
		if index < start:
			dropped.append({"id": memory_id, "reason": "memory_budget"})
			continue
		output.append({
			"memory_id": memory_id,
			"event_id": str(item.get("event_id", "")),
			"subjective_text": str(item.get("subjective_text", "")).left(260),
			"salience": clampf(float(item.get("salience", 0.5)), 0.0, 1.0),
			"valence": str(item.get("valence", "neutral")),
			"tier": str(item.get("tier", "recent")),
		})
		if not memory_id.is_empty():
			included_ids.append(memory_id)
	return output


func _compile_dialogue(transcript: Array, dropped: Array[Dictionary]) -> Array[Dictionary]:
	var start := maxi(0, transcript.size() - MAX_DIALOGUE_LINES)
	if start > 0:
		dropped.append({"id": "dialogue:older", "reason": "dialogue_budget", "count": start})
	var output: Array[Dictionary] = []
	for index: int in range(start, transcript.size()):
		var line := transcript[index] as Dictionary
		output.append({
			"speaker": str(line.get("speaker", "")).left(40),
			"text": str(line.get("text", "")).left(420),
			"kind": str(line.get("kind", "dialogue")),
		})
	return output


func _persona_core(npc: Dictionary) -> Dictionary:
	var configured: Dictionary = npc.get("persona_core", {}) as Dictionary
	if not configured.is_empty():
		return configured.duplicate(true)
	return {
		"identity": str(npc.get("kind", "异类")),
		"long_term_goal": str(npc.get("claim", "完成本轮谈判")),
		"default_strategy": str(npc.get("persona", "保持谨慎并回答可回答的问题")),
		"speech_style": "简体中文；具体、克制、保持角色身份",
		"stable_boundaries": ["不替核验员作出最终身份判断", "不声称未获授权的事实"],
	}


func _scene_mode(npc: Dictionary, mood: String) -> Dictionary:
	var modes: Dictionary = npc.get("scene_modes", {}) as Dictionary
	var selected: Dictionary = modes.get(mood, modes.get("watchful", {})) as Dictionary
	if not selected.is_empty():
		var output := selected.duplicate(true)
		output["mode_id"] = mood
		return output
	return {
		"mode_id": mood,
		"trigger": "由当前信任与压迫状态确定",
		"behavior": "维持人物核心策略，并只回应本轮已授权的语义",
		"energy": "controlled",
		"examples": [],
	}


func _director_intent(state: Dictionary, authoritative: Dictionary, belief_count: int) -> Dictionary:
	var reveal_id := str(authoritative.get("reveal_id", ""))
	var intent_id := "director:grounded_reply"
	var goal := "直接回应玩家当前问题，不主动添加新事实"
	var urgency := "foreshadow"
	var priority := 40
	if not reveal_id.is_empty():
		intent_id = "director:reveal:%s" % reveal_id
		goal = "让已通过知识锁的事实自然进入本轮回答"
		urgency = "guide"
		priority = 80
	elif int(state.get("pressure", 0)) >= 75:
		intent_id = "director:boundary"
		goal = "表现受压后的边界感，但不要替系统制造威胁后果"
		urgency = "urgent"
		priority = 70
	elif belief_count <= 1:
		intent_id = "director:invite_specific_question"
		goal = "只在自然时机鼓励核验员提出更具体、可验证的问题"
		urgency = "guide"
		priority = 50
	return {
		"intent_id": intent_id,
		"goal": goal,
		"urgency": urgency,
		"priority": priority,
		"preconditions": ["不得覆盖 authoritative_read", "不得扩展 known_beliefs"],
		"forbidden_moves": ["剧透身份答案", "替玩家提交判断", "虚构证据或人物", "宣布世界状态变化"],
		"ttl_turns": 1,
		"max_mentions": 1,
		"cooldown_turns": 2,
		"remaining_mentions": 1,
	}


func _section_sizes(sections: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	for key: Variant in sections:
		output[str(key)] = JSON.stringify(sections[key]).length()
	return output


func _band(value: int) -> String:
	if value >= 70:
		return "high"
	if value >= 40:
		return "medium"
	return "low"
