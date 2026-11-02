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
	# Если сервер упал или выдал ошибку
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		chat_reply.emit("Не получается связаться с сервером. Проверь, запущен ли Светик.", [])
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	
	# Проверяем ответ от нашего нового Python-сервера
	if data is Dictionary and data.get("speak", false) == true:
		var text_reply = data.get("text", "...")
		var actions = data.get("actions", [])
		
		# Логика спавна
		var should_spawn: bool = false
		var spawn_id: String = "ai_item"
		var spawn_name: String = "Странный предмет"
		
		for act in actions:
			var type = act.get("type", "")
			if type == "spawn_object":
				should_spawn = true
				spawn_id = act.get("id", "ai_item")
				spawn_name = act.get("name", "Загадочный артефакт")
			# Тут же обрабатываем яркость от автора, если она пришла
			elif type == "set_brightness":
				var val = act.get("value", 1.0)
				var room = get_tree().current_scene
				if room:
					var tween = create_tween()
					tween.tween_property(room, "modulate", Color(val, val, val, 1.0), 1.5)

		# Внутри _on_request_completed в Godot:
		if should_spawn:
						_spawn_generated_item_on_floor(spawn_id, spawn_name)
		else:
				print("[GODOT]: Получен текстовый ответ без необходимости спавна.")
	
# Текст диалога выведется в любом случае!
				# ОЧИСТКА МУСОРА: Удаляем технические слова, кавычки и скобки, если они пролезли в текст
		var final_clean_text: String = text_reply
		
		# Если текст начинается со слова text:, вырезаем его
		final_clean_text = final_clean_text.replace("text:", "")
		final_clean_text = final_clean_text.replace("actions:", "")
		
		# Очищаем кавычки, фигурные и квадратные скобки
		final_clean_text = final_clean_text.replace('"', "")
		final_clean_text = final_clean_text.replace("{", "").replace("}", "")
		final_clean_text = final_clean_text.replace("[", "").replace("]", "")
		
		# Убираем лишние пробелы по краям
		final_clean_text = final_clean_text.strip_edges()
		
		# Отправляем в интерфейс диалога СТРОГО чистую речь персонажа!
		chat_reply.emit(final_clean_text, actions)


	else:
		chat_reply.emit("Светик задумался и не ответил на JSON.", [])

# Вспомогательная функция, которая собирает предмет на полу и натягивает ИИ-текстуру
func _spawn_generated_item_on_floor(item_id: String, item_name: String) -> void:
	var current_scene = get_tree().current_scene
	var player = current_scene.find_child("Player", true, false)
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		
	if player:
		# Создаем физическую зону предмета
		var drop_node = Area2D.new()
		drop_node.name = "AI_Spawned_" + item_id
		
		# Загружаем сгенерированную на Python картинку с диска
		var img_path = "res://art/dynamic_generated.png"
		var sprite = Sprite2D.new()
		
		if FileAccess.file_exists(img_path):
			var img = Image.load_from_file(img_path)
			if img:
				var texture = ImageTexture.create_from_image(img)
				sprite.texture = texture
				# Ужимаем огромную картинку Stable Diffusion до аккуратного размера на полу
				sprite.scale = Vector2(0.1, 0.1) 
		
		drop_node.add_child(sprite)
		
		# Создаем коллизию, чтобы Михаил мог наступить и поднять вещь
		var collision = CollisionShape2D.new()
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = 30.0
		collision.shape = circle_shape
		drop_node.add_child(collision)
		
		# Навешиваем логику подбора в инвентарь (наш созданный менеджер)
		var pickup_script = GDScript.new()
		pickup_script.source_code = """
extends Area2D

var item_id: String
var item_name: String
var item_description: String = "Предмет, материализованный Светиком из подсознания."
var icon_path: String = "res://art/dynamic_generated.png"

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name.to_lower() == "player" or body.is_in_group("player"):
		# Кладем в наш глобальный инвентарь!
		InventoryManager.add_item(item_id, item_name, item_description, icon_path)
		queue_free()
"""
		pickup_script.reload()
		drop_node.set_script(pickup_script)
		
		# Передаем данные в объект
		drop_node.item_id = item_id
		drop_node.item_name = item_name
		
		# Размещаем объект в комнате чуть правее Михаила (на 90 пикселей)
		drop_node.global_position = player.global_position
		drop_node.global_position.x += 90.0
		drop_node.global_position.y -= 10.0 # Ровно на пол
		
		# Добавляем объект на карту уровня
		current_scene.add_child(drop_node)
		print("[РЕЖИССЕР]: Физический предмет '", item_name, "' с ИИ-текстурой успешно создан на полу!")
