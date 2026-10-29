extends Control

signal closed
var player: Node
var rows: VBoxContainer

func _ready() -> void:
	hide()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-260, -180)
	panel.custom_minimum_size = Vector2(520, 360)
	add_child(panel)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 16)
	panel.add_child(rows)

func open_container(title: String, items: Array) -> void:
	player = get_tree().get_first_node_in_group("player")
	player.can_move = false
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	rows.add_child(label)
	if items.is_empty():
		var empty := Label.new()
		empty.text = "Пусто"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rows.add_child(empty)
	for item in items:
		var button := Button.new()
		button.text = "Взять: " + str(item.name)
		button.custom_minimum_size.y = 48
		button.pressed.connect(func():
			GameState.add_item(item.id)
			GameState.set_flag("collected_" + str(item.id))
			button.disabled = true
			button.text = str(item.name) + " — взято"
		)
		rows.add_child(button)
	var close_button := Button.new()
	close_button.text = "Закрыть (Esc)"
	close_button.custom_minimum_size.y = 48
	close_button.pressed.connect(close)
	rows.add_child(close_button)
	show()
	close_button.grab_focus()

func close() -> void:
	if not visible:
		return
	hide()
	player.can_move = true
	closed.emit()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()
