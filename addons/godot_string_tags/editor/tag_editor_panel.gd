@tool
class_name TagEditorPanel
extends Control

# We hold a reference to the registry once it's available.
# It may not be available immediately on first _ready if the plugin
# is still initializing, so we check defensively before each use.
var _registry: Node

const GUI_VISIBILITY_HIDDEN = preload("uid://btaois8q4wxgi")
const GUI_VISIBILITY_VISIBLE = preload("uid://yaqw1r131wda")

@onready var _search_input: LineEdit = $VBoxContainer/SearchInput
@onready var _tree: Tree = $VBoxContainer/Tree
@onready var _tag_input: LineEdit = $VBoxContainer/HBoxContainer/TagInput
@onready var _add_button: Button = $VBoxContainer/HBoxContainer/AddButton
@onready var _feedback_label: Label = $VBoxContainer/ActionBar/FeedbackLabel
@onready var _toolbar: HBoxContainer = $VBoxContainer/ActionBar/Toolbar
@onready var _db_selector: OptionButton = $VBoxContainer/ActionBar/Toolbar/DBSelector
@onready var _new_db_button: Button = $VBoxContainer/ActionBar/Toolbar/NewDBButton
@onready var _remove_db_button: Button = $VBoxContainer/ActionBar/Toolbar/RemoveDBButton
@onready var _repair_db_button: Button = $VBoxContainer/ActionBar/Toolbar/RepairDBButton
@onready var _toolbar_toggle: Button = $VBoxContainer/ActionBar/ToolbarToggle

func _ready() -> void:
	init_ui()

#Instead of connecting our ui inputs through the editor, let's just do it here (it's quicker:P)
func init_ui() -> void:
	_search_input.text_changed.connect(_on_search_changed)
	_tag_input.text_submitted.connect(_on_tag_submitted)
	_add_button.pressed.connect(_on_add_pressed)
	_tree.item_selected.connect(_on_item_selected)
	_tree.item_mouse_selected.connect(_on_item_right_clicked)
	_new_db_button.pressed.connect(_on_new_db_pressed)
	_remove_db_button.pressed.connect(_on_remove_db_pressed)
	_db_selector.item_selected.connect(_on_db_selected)
	_repair_db_button.pressed.connect(_on_repair_db_pressed)
	_toolbar_toggle.pressed.connect(_on_toolbar_toggle_pressed)
	_tree.hide_root = true
	_tree.allow_rmb_select = true

	# Defer so the autoload is guaranteed to be ready before we query it
	call_deferred("_initial_load")


func _initial_load() -> void:
	_fetch_registry()
	if not _registry:
		push_error("TagEditorPanel: Could not find GameplayTagRegistry autoload.")
		return

	if not _registry.active_database_changed.is_connected(_refresh_db_selector):
		_registry.active_database_changed.connect(_refresh_db_selector)

	var hide_toolbar: bool = _registry.get_hide_toolbar()
	_toolbar.visible = not hide_toolbar

	_refresh_db_selector()




# -------------------------------------------------------
# Registry Access
# -------------------------------------------------------
# We fetch the registry by name from the scene tree each time
# rather than caching it permanently, because the autoload can
# be reloaded during editor restarts or plugin toggles.

func _fetch_registry() -> void:
	_registry = get_node_or_null("/root/GameplayTagRegistry")


# -------------------------------------------------------
# Tree Building
# -------------------------------------------------------
# We rebuild the entire tree from scratch on any change.
# Tag counts are small enough that this is never a performance concern.
# The tree mirrors the dot-notation hierarchy visually.

func _rebuild_tree(filter_text: String = "") -> void:
	_fetch_registry()
	_tree.clear()

	if not _registry:
		return

	# Invisible root required by Godot's Tree control
	var root := _tree.create_item()

	var all_tags : Array[String]= _registry.get_all_tags()

	# If searching, flatten to a simple list of matches rather than
	# showing broken partial hierarchy
	if not filter_text.is_empty():
		for tag in all_tags:
			if filter_text.to_lower() in tag.to_lower():
				var item := _tree.create_item(root)
				item.set_text(0, tag)
				item.set_metadata(0, tag)
		return

	# Normal mode — build the full hierarchy.
	# We keep a dict of tag -> TreeItem so we can parent children correctly.
	var item_map: Dictionary = {}

	for tag in all_tags:
		var parts := tag.split(".")
		var current_path := ""

		for i in range(parts.size()):
			var part := parts[i]
			current_path = ".".join(parts.slice(0, i + 1))

			if current_path in item_map:
				continue

			# Determine parent TreeItem
			var parent_item: TreeItem
			if i == 0:
				parent_item = root
			else:
				var parent_path := ".".join(parts.slice(0, i))
				parent_item = item_map.get(parent_path, root)

			var item := _tree.create_item(parent_item)
			item.set_text(0, part)			# Show only the leaf name, not the full path
			item.set_metadata(0, current_path)	# Store full path for operations
			item_map[current_path] = item


# -------------------------------------------------------
# Input Handling
# -------------------------------------------------------

func _on_add_pressed() -> void:
	_submit_tag(_tag_input.text.strip_edges())


func _on_tag_submitted(text: String) -> void:
	_submit_tag(text.strip_edges())


func _submit_tag(tag: String) -> void:
	_fetch_registry()

	if not GameplayTagDB.is_valid_tag_string(tag):
		_set_feedback("Invalid tag format. Use letters, numbers, underscores and dots only.", true)
		return

	if _registry.tag_exists(tag):
		_set_feedback("Tag '%s' already exists." % tag, true)
		return

	_registry.register_tag(tag)
	_tag_input.clear()
	_set_feedback("Added: %s" % tag, false)
	_rebuild_tree(_search_input.text)


func _on_search_changed(text: String) -> void:
	_rebuild_tree(text)


func _on_item_right_clicked(mouse_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		return
	var selected := _tree.get_selected()
	if not selected:
		return
	var tag: String = selected.get_metadata(0)
	var popup := PopupMenu.new()
	add_child(popup)
	popup.add_item("Copy exact '%s'" % tag, 0)
	popup.add_separator()
	popup.add_item("Rename '%s' only" % tag, 1)
	popup.add_item("Rename '%s' and children" % tag, 2)
	popup.add_separator()
	if _registry.get_tag_children(tag).is_empty(): #Only show delete only option if there are no children
		popup.add_item("Delete '%s' only" % tag, 3)
	popup.add_item("Delete '%s' and children" % tag, 4)
	popup.id_pressed.connect(func(id: int) -> void:
		_on_context_menu_selected(id, tag)
		popup.queue_free()
	)
	popup.popup_on_parent(Rect2(get_global_mouse_position(), Vector2.ZERO))


func _on_context_menu_selected(id: int, tag: String) -> void:
	_fetch_registry()
	match id:
		0:
			DisplayServer.clipboard_set(tag)
			_set_feedback("Copied: %s" % tag, false)
		1:
			_show_rename_dialog(tag, false)
		2:
			_show_rename_dialog(tag, true)
		3:
			if _registry.unregister_tag(tag, false):
				_set_feedback("Removed: %s" % tag, false)
				_rebuild_tree(_search_input.text)
			else:
				_set_feedback("Cannot delete '%s' — it still has children." % tag, true)
		4:
			if _registry.unregister_tag(tag, true):
				_set_feedback("Removed '%s' and children." % tag, false)
				_rebuild_tree(_search_input.text)
			else:
				_set_feedback("Could not remove '%s'." % tag, true)


func _show_rename_dialog(tag: String, rename_children: bool) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Rename Tag"
	dialog.size = Vector2(400, 120)
	add_child(dialog)

	var vbox := VBoxContainer.new()
	dialog.add_child(vbox)

	var label := Label.new()
	label.text = "Rename '%s' to:" % tag
	if rename_children:
		label.text += " (and all children)"
	vbox.add_child(label)

	var input := LineEdit.new()
	input.text = tag
	input.select_all()
	vbox.add_child(input)
	# Override the default OK button behavior
	dialog.confirmed.connect(func() -> void:
		var new_tag := input.text.strip_edges()
		if new_tag == tag:
			dialog.queue_free()
			return
		if not _registry.rename_tag(tag, new_tag, rename_children):
			_set_feedback("Rename failed. Check tag is valid and doesn't already exist.", true)
		else:
			if not rename_children and _registry.tag_exists(tag):
				_set_feedback("Added '%s'. '%s' kept because it still has children." % [new_tag, tag], false)
			else:
				_set_feedback("Renamed '%s' to '%s'." % [tag, new_tag], false)
			_rebuild_tree(_search_input.text)
		dialog.queue_free()
		)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)
	dialog.popup_centered()


func _on_item_selected() -> void:
	var selected := _tree.get_selected()
	if not selected:
		return
	var tag: String = selected.get_metadata(0)
	var formatted_tag = '"%s"' % tag
	DisplayServer.clipboard_set(formatted_tag)
	_set_feedback("Copied: %s" % tag, false)


func _refresh_db_selector() -> void:
	_fetch_registry()
	if not _registry:
		return
	_db_selector.clear()
	var known : Array[String] = _registry.get_known_databases()
	var active : String = _registry.get_active_database_path()
	for i in range(known.size()):
		var path: String = known[i]
		# Show just the filename, not the full path
		_db_selector.add_item(path.get_file().get_basename(), i)
		_db_selector.set_item_metadata(i, path)
		if path == active:
			_db_selector.select(i)
	_rebuild_tree()


func _on_db_selected(index: int) -> void:
	_fetch_registry()
	if not _registry:
		return
	var path: String = _db_selector.get_item_metadata(index)
	_registry.set_active_database(path)
	_rebuild_tree()


func _on_new_db_pressed() -> void:
	# Ask the user for a name via a small dialog
	var dialog := AcceptDialog.new()
	dialog.title = "New Tag Database"
	add_child(dialog)

	var vbox := VBoxContainer.new()
	dialog.add_child(vbox)

	var label := Label.new()
	label.text = "Database name (no extension):"
	vbox.add_child(label)

	var input := LineEdit.new()
	input.placeholder_text = "my_tags"
	vbox.add_child(input)

	dialog.confirmed.connect(func() -> void:
		var name := input.text.strip_edges()
		if name.is_empty():
			dialog.queue_free()
			return
		var path := "res://addons/godot_string_tags/resources/%s.tres" % name
		if not _registry.create_database(path):
			_set_feedback("Could not create database. May already exist.", true)
		else:
			_refresh_db_selector()
			_set_feedback("Created database: %s" % name, false)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered()


func _on_remove_db_pressed() -> void:
	_fetch_registry()
	if not _registry:
		return
	var active : String = _registry.get_active_database_path()
	# Confirm before removing
	var dialog := ConfirmationDialog.new()
	dialog.title = "Remove Database"
	dialog.dialog_text = "Remove '%s' from known databases?\n\nThe file will NOT be deleted." % active.get_file()
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		_registry.forget_database(active)
		_refresh_db_selector()
		_set_feedback("Removed database from list.", false)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered()


func _on_repair_db_pressed() -> void:
	_fetch_registry()
	if not _registry:
		return
	var added : int = _registry.repair_databases()
	if added > 0:
		_refresh_db_selector()
		_set_feedback("Repair found %d new database(s)." % added, false)
	else:
		_set_feedback("No new databases found. List is up to date.", false)


func _on_toolbar_toggle_pressed() -> void:
	var currently_visible := _toolbar.visible
	_toolbar.visible = not currently_visible
	_registry.set_hide_toolbar(not currently_visible)
	if currently_visible:
		_toolbar_toggle.icon = GUI_VISIBILITY_HIDDEN
	else:
		_toolbar_toggle.icon = GUI_VISIBILITY_VISIBLE

# -------------------------------------------------------
# Feedback
# -------------------------------------------------------

func _set_feedback(message: String, is_error: bool) -> void:
	_feedback_label.text = message
	var color := Color.TOMATO if is_error else Color.MEDIUM_SEA_GREEN
	_feedback_label.add_theme_color_override("font_color", color)
