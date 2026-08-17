extends Node

const Simulation := preload("res://scripts/core/case_simulation.gd")
const GameUI := preload("res://scripts/ui/game_ui.gd")

var _ui: Clause13UI
var _simulation: Clause13CaseSimulation
var _case_id := "rain_guest"
var _state := "dialogue"
var _output_path := "res://trailer/captures/rain_dialogue.png"
var _frames := 0


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--case="):
			_case_id = argument.trim_prefix("--case=")
		elif argument.begins_with("--state="):
			_state = argument.trim_prefix("--state=")
		elif argument.begins_with("--output="):
			_output_path = argument.trim_prefix("--output=")

	_ui = GameUI.new() as Clause13UI
	_ui.suppress_intro = true
	add_child(_ui)
	_simulation = Simulation.new() as Clause13CaseSimulation
	var snapshot := _simulation.start_case(_case_id)
	_ui.configure_cases(_simulation.case_catalog(), _case_id)
	_ui.render(snapshot)
	_prepare_state()



func _process(_delta: float) -> void:
	# Let fonts, layout, shader overlays, and the requested tab settle before capture.
	_frames += 1
	if _frames < 14:
		return
	set_process(false)
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(_output_path)
	print("Trailer capture %s/%s: %s (%dx%d)" % [_case_id, _state, error_string(error), image.get_width(), image.get_height()])
	get_tree().quit(0 if error == OK else 1)


func _prepare_state() -> void:
	var prompts := _prompts_for_case(_case_id)
	var talk_count := 0
	if _state in ["dialogue", "evidence", "contract", "verdict"]:
		talk_count = 2
	if _state in ["evidence", "contract", "verdict"]:
		talk_count = prompts.size()
	for index: int in range(mini(talk_count, prompts.size())):
		var result := _simulation.talk(str(prompts[index]))
		_ui.render(result.get("snapshot", _simulation.snapshot()) as Dictionary)

	if _state in ["contract", "verdict"]:
		var safe_contract := _safe_contract_for_case(_case_id)
		for slot: String in ["scope", "price", "exit"]:
			var result := _simulation.select_clause(slot, str(safe_contract.get(slot, "")))
			_ui.render(result.get("snapshot", _simulation.snapshot()) as Dictionary)
		var proposal := _simulation.propose_contract()
		_ui.render(proposal.get("snapshot", _simulation.snapshot()) as Dictionary)

	if _state == "evidence":
		for child: Node in _ui.find_children("*", "TabContainer", true, false):
			var tabs := child as TabContainer
			if tabs != null:
				tabs.current_tab = 1
				break


func _prompts_for_case(case_id: String) -> Array[String]:
	match case_id:
		"training_inspector":
			return [
				"请说出你的工号和今夜路线。",
				"验证协议究竟用来做什么？",
				"你需要进入屋内吗？",
			]
		"shadow_tailor":
			return [
				"我理解你想完成工作。你最担心什么？",
				"你只进入儿童房，能不能完成修复？",
				"你为什么想要孩子的秘密或影子？",
				"怎样定义工作完成，而不是由你满意？",
			]
		"red_rescue":
			return [
				"我相信你真想救人，也会公平处理你的地契。",
				"传感器能证明孩子还活着吗？",
				"完成救援最低需要进入哪些位置？",
				"你能接受孩子越过外门就立刻离场吗？",
			]
		_:
			return [
				"你到底是谁，为什么今晚来这里？",
				"我在听，慢慢说。我会尽量帮你。",
				"进入范围必须明确，你最低需要到哪里？",
				"雨什么时候会停？你愿意接受固定期限吗？",
			]


func _safe_contract_for_case(case_id: String) -> Dictionary:
	match case_id:
		"training_inspector":
			return {"scope": "threshold_only", "price": "signed_receipt", "exit": "upload_complete"}
		"shadow_tailor":
			return {"scope": "nursery_only", "price": "red_thread", "exit": "task_complete"}
		"red_rescue":
			return {"scope": "stairwell_4b", "price": "certified_deed", "exit": "child_safe"}
		_:
			return {"scope": "vestibule", "price": "warm_tea", "exit": "third_bell"}
