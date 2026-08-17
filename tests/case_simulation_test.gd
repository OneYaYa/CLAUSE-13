extends Node

const Simulation := preload("res://scripts/core/case_simulation.gd")

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_catalog_and_private_verdict()
	_test_dialogue_reveals_evidence()
	_test_tutorial_requires_protocol()
	_test_protocol_is_evidence_not_ending()
	_test_verdicts_define_win_and_loss()
	_test_turn_limit_requires_verdict()
	_test_compiled_context_enforces_knowledge_boundaries()
	_test_subjective_memory_links_to_immutable_event()
	_test_stale_online_reply_is_rejected()
	print("Clause 13 simulation: %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_catalog_and_private_verdict() -> void:
	var simulation := Simulation.new() as Clause13CaseSimulation
	var catalog := simulation.case_catalog()
	_expect_equal(catalog.size(), 4, "campaign exposes one tutorial and three cases")
	_expect(bool((catalog[0] as Dictionary).get("is_tutorial", false)), "tutorial is first in sequence")
	_expect_equal(str((catalog[0] as Dictionary).get("id", "")), "training_inspector", "tutorial has stable id")
	var snapshot := simulation.start_case("training_inspector")
	_expect(bool(snapshot.get("ok", false)), "tutorial starts")
	_expect_equal(int(snapshot.get("case_total", 0)), 3, "progress counts only formal cases")
	var public_json := JSON.stringify(snapshot)
	_expect(not public_json.contains("is_impostor"), "public snapshot hides true identity")
	_expect(not public_json.contains("verdict_explanation"), "public snapshot hides verdict explanation")
	_expect(not public_json.contains("safe_contract"), "public snapshot hides canonical protocol")
	_expect(not public_json.contains("npc_score"), "public snapshot hides protocol scoring")


func _test_dialogue_reveals_evidence() -> void:
	var simulation := Simulation.new() as Clause13CaseSimulation
	simulation.start_case("rain_guest")
	var before := simulation.snapshot()
	var result := simulation.talk("你为什么来？外面明明没有下雨。")
	_expect(bool(result.get("ok", false)), "natural-language question resolves")
	var after := simulation.snapshot()
	_expect_equal(int(after.get("turn", 0)), int(before.get("turn", 0)) + 1, "conversation advances one check")
	_expect("rain_anchor" in (after.get("revealed_fact_ids", []) as Array), "matching question reveals grounded fact")
	_expect((after.get("evidence", []) as Array).size() > (before.get("evidence", []) as Array).size(), "revealed fact becomes evidence")
	var dossier: Dictionary = after.get("dossier", {}) as Dictionary
	var contradictions: Array = dossier.get("contradictions", []) as Array
	_expect(bool((contradictions[0] as Dictionary).get("unlocked", false)), "fact unlocks dossier cross-check")


func _test_tutorial_requires_protocol() -> void:
	var simulation := Simulation.new() as Clause13CaseSimulation
	simulation.start_case("training_inspector")
	simulation.talk("请说出你的工号、徽章和路线。")
	var early := simulation.submit_verdict(false)
	_expect(not bool(early.get("ok", true)), "tutorial blocks verdict before protocol lesson")
	for slot: String in ["scope", "price", "exit"]:
		var ids := {"scope": "threshold_only", "price": "signed_receipt", "exit": "upload_complete"}
		_expect(bool(simulation.select_clause(slot, str(ids[slot])).get("ok", false)), "tutorial accepts %s protocol condition" % slot)
	var protocol := simulation.propose_contract()
	var checked: Dictionary = protocol.get("snapshot", {}) as Dictionary
	_expect(bool(checked.get("protocol_tested", false)), "tutorial protocol runs")
	_expect(str(checked.get("protocol_summary", "")).contains("3 / 3"), "tutorial reports evidence alignment")
	var verdict := simulation.submit_verdict(false)
	_expect_equal(str((verdict.get("snapshot", {}) as Dictionary).get("outcome", "")), "success", "trusted tutorial visitor passes")


func _test_protocol_is_evidence_not_ending() -> void:
	var simulation := Simulation.new() as Clause13CaseSimulation
	simulation.start_case("rain_guest")
	for slot: String in ["scope", "price", "exit"]:
		var ids := {"scope": "vestibule", "price": "warm_tea", "exit": "third_bell"}
		simulation.select_clause(slot, str(ids[slot]))
	var protocol := simulation.propose_contract()
	var snapshot: Dictionary = protocol.get("snapshot", {}) as Dictionary
	_expect(bool(protocol.get("ok", false)), "complete verification protocol can be proposed")
	_expect(bool(snapshot.get("protocol_tested", false)), "protocol result is exposed")
	_expect(not bool(snapshot.get("is_terminal", true)), "protocol never ends the case")


func _test_verdicts_define_win_and_loss() -> void:
	var answers := {"rain_guest": true, "shadow_tailor": true, "red_rescue": false}
	for case_id: String in answers:
		var simulation := Simulation.new() as Clause13CaseSimulation
		simulation.start_case(case_id)
		simulation.talk("请先说明你的身份和来意。")
		var result := simulation.submit_verdict(bool(answers[case_id]))
		var snapshot: Dictionary = result.get("snapshot", {}) as Dictionary
		_expect_equal(str(snapshot.get("outcome", "")), "success", "%s correct identity verdict wins" % case_id)
		_expect(bool((snapshot.get("debrief", {}) as Dictionary).get("correct", false)), "%s debrief records correct verdict" % case_id)
	var wrong := Simulation.new() as Clause13CaseSimulation
	wrong.start_case("rain_guest")
	wrong.talk("你是谁？")
	var failed: Dictionary = wrong.submit_verdict(false).get("snapshot", {}) as Dictionary
	_expect_equal(str(failed.get("outcome", "")), "failure", "wrong identity verdict loses")
	_expect_equal(str(failed.get("ending_reason", "")), "wrong_verdict", "loss reason is the verdict, not protocol")


func _test_turn_limit_requires_verdict() -> void:
	var simulation := Simulation.new() as Clause13CaseSimulation
	var state := simulation.start_case("rain_guest")
	for _index: int in range(int(state.get("max_turns", 0))):
		state = (simulation.talk("再说明一点你的身份。") as Dictionary).get("snapshot", {}) as Dictionary
	_expect(not bool(state.get("is_terminal", true)), "turn limit does not auto-fail")
	_expect_equal(str(state.get("outcome", "")), "ongoing", "case waits for player verdict")
	_expect(not bool(simulation.talk("继续说。 ").get("ok", true)), "further dialogue stops at limit")
	_expect_equal(str((simulation.submit_verdict(true).get("snapshot", {}) as Dictionary).get("outcome", "")), "success", "player can still submit verdict at limit")


func _test_compiled_context_enforces_knowledge_boundaries() -> void:
	var simulation := Simulation.new() as Clause13CaseSimulation
	simulation.start_case("rain_guest")
	var context := simulation.dialogue_context("先说说你为什么来，外面并没有下雨。")
	_expect_equal(int(context.get("context_schema_version", 0)), 2, "dialogue uses versioned context compiler")
	_expect(not context.has("public_dossier"), "NPC context never receives the player's dossier")
	_expect(not context.has("objective"), "NPC context excludes player-facing objective and verdict hints")
	var beliefs: Array = context.get("known_beliefs", []) as Array
	var belief_ids: Array[String] = []
	for raw: Variant in beliefs:
		belief_ids.append(str((raw as Dictionary).get("belief_id", "")))
	_expect("rain_anchor" in belief_ids, "current knowledge-lock fact is authorized")
	_expect("name_binding" not in belief_ids, "unearned private belief is hard-filtered")
	var trace: Dictionary = context.get("prompt_trace", {}) as Dictionary
	_expect_equal(str(trace.get("compiler_version", "")), "clause13-context-v2", "context trace records compiler version")
	_expect((trace.get("dropped", []) as Array).size() >= 1, "trace explains dropped knowledge")


func _test_subjective_memory_links_to_immutable_event() -> void:
	var simulation := Simulation.new() as Clause13CaseSimulation
	var before := simulation.start_case("shadow_tailor")
	var result := simulation.talk("我保证会给你公平的工钱，也会认真听你说。")
	var after: Dictionary = result.get("snapshot", {}) as Dictionary
	_expect(int(after.get("state_version", 0)) > int(before.get("state_version", 0)), "committed dialogue increments state version")
	var event_ids: Array = after.get("recent_event_ids", []) as Array
	_expect_equal(event_ids.size(), 1, "dialogue appends one immutable world event")
	var memory: Dictionary = after.get("memory", {}) as Dictionary
	var entries: Array = memory.get("entries", []) as Array
	_expect_equal(entries.size(), 1, "dialogue creates one subjective memory projection")
	_expect_equal(str((entries[0] as Dictionary).get("event_id", "")), str(event_ids[0]), "subjective memory keeps objective event provenance")
	_expect(float((entries[0] as Dictionary).get("salience", 0.0)) >= 0.9, "explicit promise receives high memory salience")


func _test_stale_online_reply_is_rejected() -> void:
	var simulation := Simulation.new() as Clause13CaseSimulation
	simulation.start_case("rain_guest")
	var context := simulation.dialogue_context("你是谁？")
	simulation.select_clause("scope", "vestibule")
	var turn_before := int(simulation.snapshot().get("turn", 0))
	var stale := simulation.talk_with_reply("你是谁？", "我是一个旧邻居。", {
		"case_id": str(context.get("case_id", "")),
		"snapshot_version": int(context.get("snapshot_version", -1)),
	})
	_expect(not bool(stale.get("ok", true)), "reply generated from stale snapshot is rejected")
	_expect_equal(int(simulation.snapshot().get("turn", 0)), turn_before, "stale reply cannot mutate current world state")


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("FAIL: %s" % label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	_expect(actual == expected, "%s (expected=%s actual=%s)" % [label, str(expected), str(actual)])
