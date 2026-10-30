extends Node

## HTTP-клиент диалогового сервера Светика.
signal chat_reply(text: String, actions: Array)

const SERVER_URL := "http://127.0.0.1:8000"
const TIMEOUT_SEC := 130.0

var _http: HTTPRequest


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_SEC
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


func send_chat(message: String) -> void:
	var scene_root := get_tree().current_scene
	var payload := {
		"message": message,
		"location": scene_root.name if scene_root else "unknown",
		"context": SvetikWorld.get_chat_context(scene_root),
	}
	var error := _http.request(
		SERVER_URL + "/chat",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		chat_reply.emit("Не получается связаться с сервером. Проверь, запущен ли Светик.", [])


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		chat_reply.emit("Не получается связаться с сервером. Проверь, запущен ли Светик.", [])
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if data is Dictionary and data.get("speak", false):
		chat_reply.emit(str(data.get("text", "Хм.")), data.get("actions", []))
	else:
		chat_reply.emit("Светик задумался и не ответил.", [])
