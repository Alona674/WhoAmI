extends Control

signal closed
var loot_panel: Control

func _ready() -> void:
	hide()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	loot_panel = preload("res://scenes/ui/ContainerLootPanel.tscn").instantiate()
	add_child(loot_panel)
	loot_panel.panel_closed.connect(func():
		hide()
		closed.emit()
	)

func open_container(title: String, items: Array) -> void:
	var contents: Array[Dictionary] = []
	contents.assign(items)
	loot_panel.get_node("Background/Title").text = title
	show()
	loot_panel.open_container(contents)

func close() -> void:
	loot_panel.close_panel()
