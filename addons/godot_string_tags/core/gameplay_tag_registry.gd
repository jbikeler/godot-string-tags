@tool
extends Node

const CONFIG_PATH := "res://addons/godot_string_tags/databases/gameplay_tags.cfg"
const DEFAULT_DB_PATH := "res://addons/godot_string_tags/databases/gameplay_tag_db.tres"

var _db: GameplayTagDB
var _active_path: String = ""
var _known_paths: Array[String] = []
var _config := ConfigFile.new()

signal active_database_changed


func _ready() -> void:
	_load_config()
	_load_active_db()


# -------------------------------------------------------
# Config
# -------------------------------------------------------

func _load_config() -> void:
	if _config.load(CONFIG_PATH) != OK:
		# No config yet — set up defaults
		_known_paths = [DEFAULT_DB_PATH]
		_active_path = DEFAULT_DB_PATH
		_save_config()
		return
	var known = _config.get_value("databases", "known", [DEFAULT_DB_PATH])
	_known_paths.assign(known)
	_active_path = _config.get_value("databases", "active", DEFAULT_DB_PATH)
	# Sanitize — remove any known paths that no longer exist on disk
	var valid: Array[String] = []
	for path in _known_paths:
		if ResourceLoader.exists(path):
			valid.append(path)
		else:
			push_warning("GameplayTagRegistry: Removed missing database '%s' from known list." % path)
	_known_paths = valid
	# If active path was deleted, fall back to first known or create default
	if not ResourceLoader.exists(_active_path):
		push_warning("GameplayTagRegistry: Active database '%s' not found." % _active_path)
		if not _known_paths.is_empty():
			_active_path = _known_paths[0]
		else:
			_active_path = DEFAULT_DB_PATH
			_known_paths = [DEFAULT_DB_PATH]
	_save_config()


func _save_config() -> void:
	_config.set_value("databases", "known", _known_paths)
	_config.set_value("databases", "active", _active_path)
	var result := _config.save(CONFIG_PATH)
	if result != OK:
		push_error("GameplayTagRegistry: Failed to save config.")


# -------------------------------------------------------
# Toolbar Settings
# -------------------------------------------------------

func get_hide_toolbar() -> bool:
	return EditorInterface.get_editor_settings().get_setting(
		"gameplay_tags/hide_database_toolbar") if \
		EditorInterface.get_editor_settings().has_setting(
		"gameplay_tags/hide_database_toolbar") else false


func set_hide_toolbar(value: bool) -> void:
	EditorInterface.get_editor_settings().set_setting(
		"gameplay_tags/hide_database_toolbar", value)


# -------------------------------------------------------
# DB Loading
# -------------------------------------------------------

func _load_active_db() -> void:
	if ResourceLoader.exists(_active_path):
		_db = load(_active_path)
	else:
		_db = GameplayTagDB.new()
		_save_db()


func _save_db() -> void:
	var result := ResourceSaver.save(_db, _active_path)
	if result != OK:
		push_error("GameplayTagRegistry: Failed to save database to '%s'." % _active_path)


# -------------------------------------------------------
# Database Management
# -------------------------------------------------------

## Returns all known database paths.
func get_known_databases() -> Array[String]:
	return _known_paths.duplicate()


## Returns the currently active database path.
func get_active_database_path() -> String:
	return _active_path


## Switches the active database. Returns false if path doesn't exist.
func set_active_database(path: String) -> bool:
	if not ResourceLoader.exists(path):
		push_error("GameplayTagRegistry: Database not found at '%s'." % path)
		return false
	_active_path = path
	_load_active_db()
	_save_config()
	active_database_changed.emit()
	return true


## Creates a new empty database at the given path and switches to it.
## Path should be inside res:// and end in .tres
func create_database(path: String) -> bool:
	if ResourceLoader.exists(path):
		push_error("GameplayTagRegistry: Database already exists at '%s'." % path)
		return false
	var new_db := GameplayTagDB.new()
	var result := ResourceSaver.save(new_db, path)
	if result != OK:
		push_error("GameplayTagRegistry: Failed to create database at '%s'." % path)
		return false
	if path not in _known_paths:
		_known_paths.append(path)
	_active_path = path
	_db = new_db
	_save_config()
	active_database_changed.emit()
	return true


## Removes a database from the known list. Does not delete the file.
## If it was the active database, switches to the first remaining one.
func forget_database(path: String) -> void:
	_known_paths.erase(path)
	if _active_path == path:
		if not _known_paths.is_empty():
			_active_path = _known_paths[0]
			_load_active_db()
		else:
			_active_path = DEFAULT_DB_PATH
			_known_paths = [DEFAULT_DB_PATH]
			_load_active_db()
	_save_config()
	active_database_changed.emit()


## Scans the resources folder for any .tres files that are GameplayTagDB resources
## and adds them to the known list if not already present.
## Also removes any known paths that no longer exist on disk.
func repair_databases() -> int:
	var resources_dir := "res://addons/godot_string_tags/databases/"
	var dir := DirAccess.open(resources_dir)
	if not dir:
		push_error("GameplayTagRegistry: Could not open resources directory.")
		return 0

	var added := 0

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := resources_dir + file_name
			# Try loading it and check if it's a GameplayTagDB
			var res := load(full_path)
			if res is GameplayTagDB and full_path not in _known_paths:
				_known_paths.append(full_path)
				added += 1
		file_name = dir.get_next()
	dir.list_dir_end()

	# Clean up any known paths that no longer exist
	var valid: Array[String] = []
	for path in _known_paths:
		if ResourceLoader.exists(path):
			valid.append(path)
	_known_paths = valid

	# Make sure active path is still valid
	if not ResourceLoader.exists(_active_path):
		if not _known_paths.is_empty():
			_active_path = _known_paths[0]
			_load_active_db()
		else:
			_active_path = DEFAULT_DB_PATH
			_known_paths = [DEFAULT_DB_PATH]
			_load_active_db()

	_save_config()
	active_database_changed.emit()
	return added


# -------------------------------------------------------
# Tag Registration
# -------------------------------------------------------

## Registers a new tag. Automatically registers any missing ancestor tags.
## e.g. adding "Character.Status.Burning" will also add "Character" and "Character.Status"
## Returns false if the tag already existed.
func register_tag(tag: String) -> bool:
	if not GameplayTagDB.is_valid_tag_string(tag):
		push_error("GameplayTagRegistry: Invalid tag string '%s'" % tag)
		return false
	var added := false
	# Ensure all ancestors exist first
	for ancestor in _db.get_ancestors(tag):
		if _db.add_tag(ancestor):
			added = true
	if _db.add_tag(tag):
		added = true
	if added:
		_save_db()
	return added


## Removes a tag and optionally its children. Saves if anything changed.
func unregister_tag(tag: String, remove_children: bool = true) -> bool:
	if not _db.has_tag(tag):
		return false
	if not remove_children and not get_tag_children(tag).is_empty():
		push_error("GameplayTagRegistry: Cannot delete '%s' while it still has children." % tag)
		return false
	_db.remove_tag(tag, remove_children)
	_save_db()
	return true



# -------------------------------------------------------
# Querying the Registry
# -------------------------------------------------------

func tag_exists(tag: String) -> bool:
	return _db.has_tag(tag)

func get_all_tags() -> Array[String]:
	return _db.tags.duplicate()

func get_root_tags() -> Array[String]:
	return _db.get_roots()

func get_tag_children(parent: String) -> Array[String]:
	return _db.get_children(parent)

func get_tag_ancestors(tag: String) -> Array[String]:
	return _db.get_ancestors(tag)


## Renames a tag and optionally all of its children.
## Returns false if old_tag doesn't exist or new_tag is invalid.
func rename_tag(old_tag: String, new_tag: String, rename_children: bool) -> bool:
	if not _db.has_tag(old_tag):
		push_error("GameplayTagRegistry: Tag '%s' does not exist." % old_tag)
		return false
	if not GameplayTagDB.is_valid_tag_string(new_tag):
		push_error("GameplayTagRegistry: Invalid tag string '%s'" % new_tag)
		return false
	if _db.has_tag(new_tag):
		push_error("GameplayTagRegistry: Tag '%s' already exists." % new_tag)
		return false
	_db.rename_tag(old_tag, new_tag, rename_children)
	_save_db()
	return true
