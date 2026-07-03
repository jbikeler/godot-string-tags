@tool
extends PopupPanel

@onready var alert_message: Label = $PanelContainer/MarginContainer/VBoxContainer/AlertMessage
@onready var search_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/SearchButton
@onready var delete_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/DeleteButton

signal search_requested
signal delete_confirmed


func setup(message: String, has_references: bool) -> void:
	alert_message.text = message
	search_button.visible = has_references
	delete_button.text = "Delete Anyway" if has_references else "Delete"


func _ready() -> void:
	search_button.pressed.connect(func() -> void:
		search_requested.emit()
		queue_free()
	)
	delete_button.pressed.connect(func() -> void:
		delete_confirmed.emit()
		queue_free()
	)
	popup_hide.connect(func() -> void:
		queue_free()
	)
	
