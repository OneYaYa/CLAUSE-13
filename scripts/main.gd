extends Node

const Simulation := preload("res://scripts/core/case_simulation.gd")
const GameUI := preload("res://scripts/ui/game_ui.gd")
const DialogueService := preload("res://scripts/services/dialogue_service.gd")

var _simulation: Clause13CaseSimulation
var _ui: Clause13UI
var _catalog: Array[Dictionary] = []
var _current_index := 0
var _dialogue_service: Clause13DialogueService


func _ready() -> void:
	_ui = GameUI.new() as Clause13UI
	add_child(_ui)
	_ui.case_selected.connect(_on_case_selected)
	_ui.player_submitted.connect(_on_player_submitted)
	_ui.clause_selected.connect(_on_clause_selected)
	_ui.propose_requested.connect(_on_propose_requested)
	_ui.sign_requested.connect(_on_sign_requested)
	_ui.restart_requested.connect(_on_restart_requested)
	_ui.next_case_requested.connect(_on_next_case_requested)
	_dialogue_service = DialogueService.new() as Clause13DialogueService
	_dialogue_service.reply_ready.connect(_on_dialogue_reply_ready)
	_dialogue_service.status_changed.connect(_ui.set_ai_status)
	add_child(_dialogue_service)
	_simulation = Simulation.new() as Clause13CaseSimulation
	_simulation.case_ended.connect(_on_case_ended)
	_catalog = _simulation.case_catalog()
	if _catalog.is_empty():
		return
	_start_case(0)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("focus_input"):
		_ui.focus_input()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart_case"):
		_on_restart_requested()
		get_viewport().set_input_as_handled()


func _start_case(index: int) -> void:
	if _catalog.is_empty():
		return
	_current_index = posmod(index, _catalog.size())
	var case_id := str(_catalog[_current_index].get("id", ""))
	_ui.configure_cases(_catalog, case_id)
	var snapshot := _simulation.start_case(case_id)
	_ui.render(snapshot)
	_ui.focus_input()


func _on_case_selected(case_id: String) -> void:
	for index: int in range(_catalog.size()):
		if str(_catalog[index].get("id", "")) == case_id:
			_start_case(index)
			return


func _on_player_submitted(text: String) -> void:
	var context := _simulation.dialogue_context(text)
	if context.is_empty():
		_ui.show_result(_simulation.talk(text))
		return
	_ui.set_thinking(true)
	_dialogue_service.request_reply(context, text)


func _on_dialogue_reply_ready(player_text: String, reply: String, _provider: String) -> void:
	_ui.set_thinking(false)
	_ui.show_result(_simulation.talk_with_reply(player_text, reply))
	_ui.focus_input()


func _on_clause_selected(slot: String, clause_id: String) -> void:
	_ui.show_result(_simulation.select_clause(slot, clause_id))


func _on_propose_requested() -> void:
	_ui.show_result(_simulation.propose_contract())


func _on_sign_requested() -> void:
	_ui.show_result(_simulation.sign_contract())


func _on_restart_requested() -> void:
	_dialogue_service.cancel_pending()
	_ui.render(_simulation.restart())
	_ui.focus_input()


func _on_next_case_requested() -> void:
	_start_case(_current_index + 1)


func _on_case_ended(outcome: String, snapshot: Dictionary) -> void:
	_ui.render(snapshot)
	_ui.show_outcome(outcome, snapshot)
