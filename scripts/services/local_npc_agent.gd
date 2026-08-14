class_name LocalNpcAgent
extends RefCounted


func decide(context: Dictionary, player_text: String) -> Dictionary:
	var case_data: Dictionary = context.get("case", {}) as Dictionary
	var state: Dictionary = context.get("state", {}) as Dictionary
	var npc: Dictionary = case_data.get("npc", {}) as Dictionary
	var responses: Dictionary = npc.get("responses", {}) as Dictionary
	var compact := player_text.to_lower().replace(" ", "")
	var intent := "conversation"
	var topic := "general"
	var trust_delta := 0
	var pressure_delta := 0

	if _contains_any(compact, ["闭嘴", "怪物", "骗我", "撒谎", "命令你", "否则", "威胁"]):
		intent = "provoke"
		topic = "threat"
		trust_delta = -8
		pressure_delta = 12
	elif _contains_any(compact, ["别怕", "我理解", "我听着", "不会伤害", "帮你", "相信我", "慢慢说", "我在"]):
		intent = "empathize"
		topic = "empathy"
		trust_delta = 6
		pressure_delta = -7
	elif _contains_any(compact, ["交换", "条件", "代价", "给你", "你要什么", "想得到", "报酬"]):
		intent = "bargain"
		topic = "price"
		trust_delta = 3
		pressure_delta = -2
	elif _contains_any(compact, ["离开", "期限", "多久", "什么时候走", "何时走", "结束条件"]):
		intent = "question"
		topic = "exit"
		trust_delta = 1
	elif _contains_any(compact, ["范围", "进去哪里", "去哪里", "哪间", "哪些地方", "门槛", "越界"]):
		intent = "question"
		topic = "scope"
		trust_delta = 1
	elif _contains_any(compact, ["规则", "限制", "邀请", "条款", "约束", "不能做"]):
		intent = "question"
		topic = "rule"
		trust_delta = 1
	elif _contains_any(compact, ["为什么来", "来做什么", "目的", "想要什么", "诉求", "帮谁"]):
		intent = "question"
		topic = "motive"
		trust_delta = 1
	elif _contains_any(compact, ["你是谁", "名字", "身份", "从哪来", "认识你"]):
		intent = "question"
		topic = "identity"
		trust_delta = 1

	var trust_after := clampi(int(state.get("trust", 0)) + trust_delta, 0, 100)
	var reveal := _eligible_fact(case_data, state, topic, compact, trust_after)
	var reply := ""
	if not reveal.is_empty():
		reply = str(reveal.get("reply", "你问到了重点。"))
	elif intent == "provoke":
		reply = str(responses.get("threat", "公证员，别把礼貌当成我的软弱。门外的东西也会失去耐心。"))
	elif intent == "empathize":
		reply = str(responses.get("empathy", "……至少你愿意听。那就别急着替我写结局。"))
	elif responses.has(topic):
		reply = str(responses.get(topic, ""))
	else:
		reply = str(responses.get("general", "我听见了。但漂亮话不是条款——问清楚，或者给我一份能签的契约。"))

	var memory: Dictionary = state.get("memory", {}) as Dictionary
	var promises: Array = memory.get("promises", []) as Array
	if not promises.is_empty() and intent == "empathize" and reveal.is_empty():
		reply += " 我记得你刚才的保证。别让它变成空话。"
	return {
		"reply": reply,
		"intent": intent,
		"topic": topic,
		"trust_delta": trust_delta,
		"pressure_delta": pressure_delta,
		"reveal_id": str(reveal.get("id", "")),
	}


func _eligible_fact(case_data: Dictionary, state: Dictionary, topic: String, compact: String, trust: int) -> Dictionary:
	var revealed: Array = state.get("revealed_fact_ids", []) as Array
	for raw: Variant in case_data.get("facts", []) as Array:
		var fact := raw as Dictionary
		var fact_id := str(fact.get("id", ""))
		if fact_id in revealed or trust < int(fact.get("min_trust", 0)):
			continue
		var topic_match := str(fact.get("topic", "")) == topic
		var keyword_match := _contains_any(compact, fact.get("trigger_keywords", []) as Array)
		if topic_match or keyword_match:
			return fact
	return {}


func _contains_any(text: String, values: Array) -> bool:
	for raw: Variant in values:
		if text.contains(str(raw).to_lower().replace(" ", "")):
			return true
	return false

