extends Node

const Simulation := preload("res://scripts/core/case_simulation.gd")

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_catalog_and_public_snapshot()
	_test_dialogue_reveals_evidence()
	_test_safe_contracts()
	_test_dangerous_contract_breaches()
	_test_deadline_failure()
	print("Clause 13 simulation: %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_catalog_and_public_snapshot() -> void:
	var simulation := Simulation.new() as Clause13CaseSimulation
	var catalog := simulation.case_catalog()
	_expect_equal(catalog.size(), 3, "campaign exposes three short cases")
	var snapshot := simulation.start_case("rain_guest")
	_expect(bool(snapshot.get("ok", false)), "first case starts")
	_expect_equal(int(snapshot.get("case_number", 0)), 1, "case metadata is projected")
	var public_json := JSON.stringify(snapshot)
	_expect(not public_json.contains("safe_contract"), "public snapshot hides canonical safe contract")
	_expect(not public_json.contains("npc_score"), "public snapshot hides negotiation scoring")
	_expect(not public_json.contains("rain_anchor"), "unrevealed fact ids stay private")
	var dossier: Dictionary = snapshot.get("dossier", {}) as Dictionary
	_expect_equal(str(dossier.get("archive_id", "")), "C13-W-017", "public snapshot exposes interview dossier")
	_expect_equal((dossier.get("risk_flags", []) as Array).size(), 3, "dossier exposes concise risk flags")
	var contradictions: Array = dossier.get("contradictions", []) as Array
	_expect_equal(contradictions.size(), 3, "dossier exposes three verification leads")
	_expect(not bool((contradictions[0] as Dictionary).get("unlocked", true)), "unverified archive record starts redacted")
	_expect(str((contradictions[0] as Dictionary).get("record", "leak")).is_empty(), "redacted dossier does not leak hidden answer")


func _test_dialogue_reveals_evidence() -> void:
	var simulation := Simulation.new() as Clause13CaseSimulation
	simulation.start_case("rain_guest")
	var before := simulation.snapshot()
	var result := simulation.talk("你为什么来？外面明明没有下雨。")
	_expect(bool(result.get("ok", false)), "natural-language question resolves")
	var after := simulation.snapshot()
	_expect_equal(int(after.get("turn", 0)), int(before.get("turn", 0)) + 1, "conversation advances one cycle")
	_expect("rain_anchor" in (after.get("revealed_fact_ids", []) as Array), "matching question reveals a grounded fact")
	_expect((after.get("evidence", []) as Array).size() > (before.get("evidence", []) as Array).size(), "revealed fact becomes player evidence")
	var dossier: Dictionary = after.get("dossier", {}) as Dictionary
	var contradictions: Array = dossier.get("contradictions", []) as Array
	_expect(bool((contradictions[0] as Dictionary).get("unlocked", false)), "revealed fact unlocks matching dossier verification")
	_expect(not str((contradictions[0] as Dictionary).get("record", "")).is_empty(), "unlocked verification exposes archive comparison")
	var trust_before := int(after.get("trust", 0))
	simulation.talk("我在听，也愿意帮你。慢慢说。")
	_expect(int(simulation.snapshot().get("trust", 0)) > trust_before, "empathetic language raises trust")


func _test_safe_contracts() -> void:
	var contracts := {
		"rain_guest": {"scope": "vestibule", "price": "warm_tea", "exit": "third_bell", "empathy": 1},
		"shadow_tailor": {"scope": "nursery_only", "price": "red_thread", "exit": "task_complete", "empathy": 3},
		"red_rescue": {"scope": "stairwell_4b", "price": "certified_deed", "exit": "child_safe", "empathy": 2},
	}
	for case_id: String in contracts:
		var simulation := Simulation.new() as Clause13CaseSimulation
		simulation.start_case(case_id)
		var contract: Dictionary = contracts[case_id] as Dictionary
		for index: int in range(int(contract.get("empathy", 0))):
			simulation.talk("我理解你，也会公平帮你。别怕，慢慢说。")
		for slot: String in ["scope", "price", "exit"]:
			var selected := simulation.select_clause(slot, str(contract.get(slot, "")))
			_expect(bool(selected.get("ok", false)), "%s accepts valid %s option" % [case_id, slot])
		var proposal := simulation.propose_contract()
		_expect(bool((proposal.get("snapshot", {}) as Dictionary).get("contract_accepted", false)), "%s NPC accepts fair constrained contract after rapport" % case_id)
		var signed := simulation.sign_contract()
		var ending: Dictionary = signed.get("snapshot", {}) as Dictionary
		_expect_equal(str(ending.get("outcome", "")), "success", "%s safe clauses produce success" % case_id)
		_expect_equal(str((ending.get("debrief", {}) as Dictionary).get("grade", "")), "S", "%s safe solution receives S grade" % case_id)


func _test_dangerous_contract_breaches() -> void:
	var simulation := Simulation.new() as Clause13CaseSimulation
	simulation.start_case("rain_guest")
	simulation.select_clause("scope", "whole_house")
	simulation.select_clause("price", "true_name")
	simulation.select_clause("exit", "guest_decides")
	var proposal := simulation.propose_contract()
	_expect(bool((proposal.get("snapshot", {}) as Dictionary).get("contract_accepted", false)), "tempting dangerous contract is easy for NPC to accept")
	var ending := simulation.sign_contract()
	_expect_equal(str((ending.get("snapshot", {}) as Dictionary).get("outcome", "")), "failure", "forbidden loophole causes a deterministic breach")


func _test_deadline_failure() -> void:
	var simulation := Simulation.new() as Clause13CaseSimulation
	var state := simulation.start_case("rain_guest")
	var guard := 0
	while not bool(state.get("is_terminal", false)) and guard < 20:
		state = (simulation.talk("你再说一点。") as Dictionary).get("snapshot", {}) as Dictionary
		guard += 1
	_expect(guard < 20, "conversation deadline terminates in finite cycles")
	_expect_equal(str(state.get("outcome", "")), "failure", "missing the deadline fails the case")


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("FAIL: %s" % label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	_expect(actual == expected, "%s (expected=%s actual=%s)" % [label, str(expected), str(actual)])
