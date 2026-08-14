extends Node

const Simulation := preload("res://scripts/core/case_simulation.gd")
const GameUI := preload("res://scripts/ui/game_ui.gd")

var _ui: Clause13UI
var _frames := 0
var _case_id := "rain_guest"
var _output_path := "res://artifacts/clause13_preview.png"


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--case="):
			_case_id = argument.trim_prefix("--case=")
		elif argument.begins_with("--output="):
			_output_path = argument.trim_prefix("--output=")
	_ui = GameUI.new() as Clause13UI
	_ui.suppress_intro = true
	add_child(_ui)
	var simulation := Simulation.new() as Clause13CaseSimulation
	var snapshot := simulation.start_case(_case_id)
	_ui.configure_cases(simulation.case_catalog(), _case_id)
	_ui.render(snapshot)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames < 12:
		return
	set_process(false)
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(_output_path)
	print("Preview capture %s: %s (%dx%d)" % [_case_id, error_string(error), image.get_width(), image.get_height()])
	get_tree().quit(0 if error == OK else 1)
