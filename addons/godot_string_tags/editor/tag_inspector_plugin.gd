@tool
class_name TagInspectorPlugin
extends EditorInspectorPlugin

const POPUP_SCENE := preload("res://addons/godot_string_tags/editor/tag_select_popup.tscn")

func _can_handle(object: Object) -> bool:
	return true


func _parse_property(
	object: Object,
	type: Variant.Type,
	name: String,
	hint_type: PropertyHint,
	hint_string: String,
	usage_flags: int,
	wide: bool
) -> bool:
	if type == TYPE_OBJECT and hint_string == "GameplayTagContainer":
		var editor := TagContainerProperty.new()
		add_property_editor(name, editor)
		return true

	return false


class TagContainerProperty extends EditorProperty:

	var _container: GameplayTagContainer
	var _registry: Node
	var _vbox: VBoxContainer
	var _tags_vbox: VBoxContainer
	var _edit_button: Button
	var _updating := false


	func _ready() -> void:
		_build_ui()


	func _fetch_registry() -> void:
		_registry = get_tree().root.get_node_or_null("GameplayTagRegistry")


	func _build_ui() -> void:
		_vbox = VBoxContainer.new()
		_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(_vbox)

		_tags_vbox = VBoxContainer.new()
		_vbox.add_child(_tags_vbox)

		_edit_button = Button.new()
		_edit_button.text = "Edit Tags"
		_edit_button.pressed.connect(_on_edit_pressed)
		_vbox.add_child(_edit_button)


	func _update_property() -> void:
		var new_container = get_edited_object().get(get_edited_property())

		if not new_container or not new_container is GameplayTagContainer:
			return

		_container = new_container

		if not _container.tags_changed.is_connected(_on_tags_changed):
			_container.tags_changed.connect(_on_tags_changed)

		_updating = true
		_refresh_tag_list()
		_updating = false


	func _refresh_tag_list() -> void:
		for child in _tags_vbox.get_children():
			child.queue_free()

		if not _container or _container.tags.is_empty():
			var empty_label := Label.new()
			empty_label.text = "No tags assigned."
			empty_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
			_tags_vbox.add_child(empty_label)
			return

		for tag in _container.tags:
			var row := HBoxContainer.new()
			_tags_vbox.add_child(row)

			var label := Label.new()
			label.text = tag
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)

			var remove_btn := Button.new()
			remove_btn.text = "x"
			remove_btn.tooltip_text = "Remove %s" % tag
			remove_btn.pressed.connect(func() -> void: _on_remove_tag(tag))
			row.add_child(remove_btn)


	func _on_tags_changed() -> void:
		if _updating:
			return
		_updating = true
		_refresh_tag_list()
		emit_changed(get_edited_property(), _container)
		_updating = false


	func _on_remove_tag(tag: String) -> void:
		if not _container or _updating:
			return
		_container.remove_tag(tag)
		emit_changed(get_edited_property(), _container)
		_refresh_tag_list()


	func _on_edit_pressed() -> void:
		_fetch_registry()
		if not _registry:
			return

		if not _container:
			var obj := get_edited_object()
			var prop := get_edited_property()
			var new_container := GameplayTagContainer.new()
			obj.set(prop, new_container)
			emit_changed(prop, new_container)
			_container = new_container

		var popup := POPUP_SCENE.instantiate()
		add_child(popup)
		popup.open_in_assign_mode(_registry, _container)
