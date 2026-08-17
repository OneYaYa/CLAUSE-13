class_name Clause13DialogueService
extends Node


signal reply_ready(player_text: String, reply: String, provider: String, request_meta: Dictionary)
signal status_changed(status: String, detail: String)

@export var endpoint := "http://127.0.0.1:8793/api/dialogue"
@export var health_endpoint := "http://127.0.0.1:8793/health"
@export var timeout_seconds := 18.0

var _http: HTTPRequest
var _player_text := ""
var _busy := false
var _online_ready := false
var _request_kind := ""
var _request_meta: Dictionary = {}


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = timeout_seconds
	_http.use_threads = true
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_probe()


func request_reply(context: Dictionary, player_text: String) -> void:
	var clean := player_text.strip_edges().left(500)
	if clean.is_empty():
		return
	var request_meta := {
		"case_id": str(context.get("case_id", "")),
		"turn_id": str(context.get("turn_id", "")),
		"snapshot_version": int(context.get("snapshot_version", -1)),
	}
	if _busy or not _online_ready:
		reply_ready.emit(clean, "", "local", request_meta)
		return
	_request_meta = request_meta
	_busy = true
	_request_kind = "dialogue"
	_player_text = clean
	status_changed.emit("thinking", "异类人格模型正在组织回答……")
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	var error := _http.request(endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify({
		"message": clean,
		"context": context,
	}))
	if error != OK:
		_fallback("在线请求无法启动")


func cancel_pending() -> void:
	if not _busy:
		return
	_http.cancel_request()
	_busy = false
	_request_kind = ""
	_player_text = ""
	_request_meta.clear()
	status_changed.emit("local", "在线请求已取消，继续使用本地人格")


func is_busy() -> bool:
	return _busy


func _probe() -> void:
	if _busy:
		return
	_busy = true
	_request_kind = "health"
	var error := _http.request(health_endpoint, PackedStringArray(["Accept: application/json"]), HTTPClient.METHOD_GET)
	if error != OK:
		_busy = false
		_online_ready = false
		status_changed.emit("local", "未发现在线人格服务；使用本地 AI 降级")


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var kind := _request_kind
	_request_kind = ""
	_busy = false
	if kind.is_empty():
		return
	if kind == "health":
		var health: Variant = JSON.parse_string(body.get_string_from_utf8())
		_online_ready = result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300 \
			and health is Dictionary and bool((health as Dictionary).get("configured", false))
		status_changed.emit("online" if _online_ready else "local", "在线人格服务已连接" if _online_ready else "在线人格服务不可用；使用本地 AI 降级")
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_fallback("在线人格服务暂不可用")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_fallback("在线响应格式无效")
		return
	var reply := str((parsed as Dictionary).get("reply", "")).strip_edges().left(600)
	if reply.is_empty():
		_fallback("在线人格没有返回对白")
		return
	var message := _player_text
	_player_text = ""
	var meta := _request_meta.duplicate(true)
	meta["generation_trace"] = {
		"provider": str((parsed as Dictionary).get("provider", "openai")),
		"model": str((parsed as Dictionary).get("model", "")),
		"prompt_hash": str((parsed as Dictionary).get("prompt_hash", "")),
		"action": str((parsed as Dictionary).get("action", "")),
		"referenced_ids": ((parsed as Dictionary).get("referenced_ids", []) as Array).duplicate(),
		"proposed_actions": ((parsed as Dictionary).get("proposed_actions", []) as Array).duplicate(true),
	}
	_request_meta.clear()
	status_changed.emit("online", "在线人格回应已接收；契约裁决仍由本地核心执行")
	reply_ready.emit(message, reply, "online", meta)


func _fallback(reason: String) -> void:
	var message := _player_text
	_player_text = ""
	var meta := _request_meta.duplicate(true)
	_request_meta.clear()
	_online_ready = false
	_busy = false
	_request_kind = ""
	status_changed.emit("local", "%s；本轮使用本地人格" % reason)
	reply_ready.emit(message, "", "local_fallback", meta)
