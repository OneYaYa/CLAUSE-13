extends Node

const Simulation := preload("res://scripts/core/case_simulation.gd")
const GameUI := preload("res://scripts/ui/game_ui.gd")

var _advanced := false


func _ready() -> void:
	var ui := GameUI.new() as Clause13UI
	ui.suppress_intro = true
	ui.next_case_requested.connect(_on_advanced)
	add_child(ui)
	var simulation := Simulation.new() as Clause13CaseSimulation
	var snapshot := simulation.start_case("rain_guest")
	simulation.talk("你是谁？")
	snapshot = simulation.submit_verdict(true).get("snapshot", {}) as Dictionary
	ui.configure_cases(simulation.case_catalog(), "rain_guest")
	ui.render(snapshot)
	ui.show_outcome("success", snapshot)
	await get_tree().create_timer(2.25).timeout
	if not _advanced:
		push_error("FAIL: correct verdict did not request automatic next case")
	print("Clause 13 UI progression: 1 check, %d failures" % [0 if _advanced else 1])
	get_tree().quit(0 if _advanced else 1)


func _on_advanced() -> void:
	_advanced = true
