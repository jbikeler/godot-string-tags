@tool
extends EditorInspectorPlugin

const POPUP_SCENE := preload("res://addons/godot_string_tags/editor/tag_select_popup.tscn")


func _can_handle(object: Object) -> bool:
	print("_can_handle called with: ", object)
	return true

func _parse_begin(object: Object) -> void:
	var script = object.get_script()
	if not script:
		return
	if script.resource_path != "res://addons/godot_string_tags/core/gameplay_tag_container.gd":
		return
	var container := object as GameplayTagContainer
	var editor := TagContainerProperty.new()
	editor.setup(container)
	add_custom_control(editor)

func _parse_end(object: Object) -> void:
	pass


func _parse_property(
	object: Object,
	type: Variant.Type,
	name: String,
	hint_type: PropertyHint,
	hint_string: String,
	usage_flags: int,
	wide: bool
) -> bool:
	var script = object.get_script()
	if script and script.resource_path == "res://addons/godot_string_tags/core/gameplay_tag_container.gd":
		if name == "tags":
			return true
	return false


class TagContainerProperty extends VBoxContainer:
	var _container: GameplayTagContainer
	var _registry: Node
	var _tags_vbox: VBoxContainer
	var _edit_button: Button
	var _updating := false

	func _build_ui() -> void:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		_tags_vbox = VBoxContainer.new()
		_tags_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(_tags_vbox)

		_edit_button = Button.new()
		_edit_button.text = "Edit Tags"
		_edit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_edit_button.pressed.connect(_on_edit_pressed)
		add_child(_edit_button)


	func setup(container: GameplayTagContainer) -> void:
		_container = container


	func _ready() -> void:
		_build_ui()
		if _container:
			if not _container.tags_changed.is_connected(_on_tags_changed):
				_container.tags_changed.connect(_on_tags_changed)
			_refresh_tag_list()


	func _fetch_registry() -> void:
		_registry = get_tree().root.get_node_or_null("GameplayTagRegistry")


	func _refresh_tag_list() -> void:
		for child in _tags_vbox.get_children():
			child.queue_free()

		if not _container or _container.tags.is_empty():
			var empty_label := Label.new()
			empty_label.text = "No tags assigned."
			empty_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
			_tags_vbox.add_child(empty_label)
		else:
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

		# Tell the inspector our size has changed
		update_minimum_size()


	func _on_tags_changed() -> void:
		if _updating:
			return
		_updating = true
		_refresh_tag_list()
		_updating = false


	func _on_remove_tag(tag: String) -> void:
		if not _container or _updating:
			return
		_container.remove_tag(tag)
		_refresh_tag_list()


	func _on_edit_pressed() -> void:
		_fetch_registry()
		if not _registry or not _container:
			return

		var popup := POPUP_SCENE.instantiate()
		add_child(popup)
		popup.open_in_assign_mode(_registry, _container)
