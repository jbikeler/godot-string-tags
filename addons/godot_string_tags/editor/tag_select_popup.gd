@tool
extends PopupPanel

enum MenuMode {
	ASSIGN_CONTAINER,
	CLIPBOARD
}

var _mode: MenuMode = MenuMode.ASSIGN_CONTAINER
var _registry: Node
var _container: GameplayTagContainer
var _selected_tags: Array[String] = []

@onready var search_input: LineEdit = $VBoxContainer/SearchInput
@onready var tag_list: VBoxContainer = $VBoxContainer/ScrollContainer/TagList
@onready var confirm_box: VBoxContainer = $VBoxContainer/ConfirmBox
@onready var clipboard_label: Label = $VBoxContainer/ConfirmBox/ClipboardLabel
@onready var confirm_button: Button = $VBoxContainer/ConfirmBox/ConfirmButton


# -------------------------------------------------------
# Entry Points
# -------------------------------------------------------

## Called by the inspector plugin for container assignment modeMenu
func open_in_assign_mode(registry: Node, container: GameplayTagContainer) -> void:
	_mode = MenuMode.ASSIGN_CONTAINER
	_registry = registry
	_container = container
	confirm_box.visible = false
	_rebuild_list("")
	popup_centered()


## Called by plugin.gd for clipboard copy mode
func open_in_clipboard_mode(registry: Node) -> void:
	_mode = MenuMode.CLIPBOARD
	_registry = registry
	_container = null
	_selected_tags.clear()
	confirm_box.visible = true
	_rebuild_list("")
	popup_centered()


# -------------------------------------------------------
# UI
# -------------------------------------------------------


func _rebuild_list(filter: String) -> void:
	for child in tag_list.get_children():
		child.queue_free()

	for tag in _registry.get_all_tags():
		if not filter.is_empty() and filter.to_lower() not in tag.to_lower():
			continue

		var check := CheckBox.new()
		check.text = tag

		if _mode == MenuMode.ASSIGN_CONTAINER:
			check.button_pressed = _container.has_exact(tag)
			check.toggled.connect(func(pressed: bool) -> void:
				if pressed:
					_container.add_tag(tag)
				else:
					_container.remove_tag(tag)
			)
		else:
			check.button_pressed = tag in _selected_tags
			check.toggled.connect(func(pressed: bool) -> void:
				if pressed:
					if tag not in _selected_tags:
						_selected_tags.append(tag)
				else:
					_selected_tags.erase(tag)
				_update_clipboard_label()
			)

		tag_list.add_child(check)


func _update_clipboard_label() -> void:
	if clipboard_label:
		clipboard_label.text = "%d tag(s) selected" % _selected_tags.size()


func _on_search_changed(text: String) -> void:
	_rebuild_list(text)


# -------------------------------------------------------
# Confirm
# -------------------------------------------------------

func _on_confirm_pressed() -> void:
	if _selected_tags.is_empty():
		hide()
		return
	# Format as one quoted string per line
	var lines: Array[String] = []
	for tag in _selected_tags:
		lines.append('"%s"' % tag)
	# Only use a newline if there are more than 3 items
	var join_char := ",\n" if lines.size() > 3 else ", "
	var result := join_char.join(lines)
	DisplayServer.clipboard_set(result)
	hide()
