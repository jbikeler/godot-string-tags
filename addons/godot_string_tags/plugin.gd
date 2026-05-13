@tool
extends EditorPlugin

const TAG_REGISTRY_PATH := "res://addons/godot_string_tags/core/gameplay_tag_registry.gd"
const TAG_PANEL_SCENE := preload("res://addons/godot_string_tags/editor/tag_editor_panel.tscn")
const TAG_POPUP_SCENE := preload("res://addons/godot_string_tags/editor/tag_select_popup.tscn")

var _panel: Control
var _inspector_plugin: EditorInspectorPlugin
var _clipboard_popup: Window = null


func _enable_plugin() -> void:
	add_autoload_singleton("GameplayTagRegistry", TAG_REGISTRY_PATH)
	_register_editor_settings()


func _disable_plugin() -> void:
	remove_autoload_singleton("GameplayTagRegistry")


func _enter_tree() -> void:
	_panel = TAG_PANEL_SCENE.instantiate()
	add_control_to_bottom_panel(_panel, "Gameplay Tags")
	_inspector_plugin = preload("res://addons/godot_string_tags/editor/tag_inspector_plugin.gd").new()
	add_inspector_plugin(_inspector_plugin)


func _exit_tree() -> void:
	if _panel:
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
		_panel = null
	if _inspector_plugin:
		remove_inspector_plugin(_inspector_plugin)
		_inspector_plugin = null


# -------------------------------------------------------
# Editor Settings
# -------------------------------------------------------

func _register_editor_settings() -> void:
	var settings := EditorInterface.get_editor_settings()

	# Toolbar toggle preference
	if not settings.has_setting("gameplay_tags/hide_database_toolbar"):
		settings.set_setting("gameplay_tags/hide_database_toolbar", false)

	# Tag picker shortcut
	if not settings.has_setting("gameplay_tags/shortcuts/open_tag_picker"):
		var shortcut_event := InputEventKey.new()
		shortcut_event.keycode = KEY_T
		shortcut_event.ctrl_pressed = true
		shortcut_event.shift_pressed = true

		var shortcut := Shortcut.new()
		shortcut.events = [shortcut_event]

		settings.set_setting("gameplay_tags/shortcuts/open_tag_picker", shortcut)

	settings.add_property_info({
		"name": "gameplay_tags/shortcuts/open_tag_picker",
		"type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "Shortcut"
	})


# -------------------------------------------------------
# Shortcut Input
# -------------------------------------------------------

func _shortcut_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	var settings := EditorInterface.get_editor_settings()
	if not settings.has_setting("gameplay_tags/shortcuts/open_tag_picker"):
		return
	var shortcut: Shortcut = settings.get_setting("gameplay_tags/shortcuts/open_tag_picker")
	if not shortcut or not shortcut.matches_event(event):
		return
	# Consume the event so it doesn't type into the script editor
	get_viewport().set_input_as_handled()
	_open_clipboard_popup()


func _open_clipboard_popup() -> void:
	if _clipboard_popup and is_instance_valid(_clipboard_popup):
		return
	var registry := get_node_or_null("/root/GameplayTagRegistry")
	if not registry:
		push_error("TagPicker: Could not find GameplayTagRegistry.")
		return
	_clipboard_popup = TAG_POPUP_SCENE.instantiate()
	EditorInterface.get_base_control().add_child(_clipboard_popup)
	_clipboard_popup.popup_hide.connect(func() -> void:
		_clipboard_popup.queue_free()
		_clipboard_popup = null
	)
	_clipboard_popup.open_in_clipboard_mode(registry)
	
