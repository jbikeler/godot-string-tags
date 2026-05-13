@tool
class_name GameplayTagDB
extends Resource

## The flat list of all registered tag strings.
## Stored in dot-notation format, e.g. "Character.Status.Burning"
@export var tags: Array[String] = []

static var _tag_regex: RegEx = null

## Returns true if the exact tag string exists in the database.
func has_tag(tag: String) -> bool:
	return tag in tags


## Adds a tag if it doesn't already exist. Returns true if it was added.
func add_tag(tag: String) -> bool:
	if tag in tags:
		return false
	tags.append(tag)
	tags.sort()
	return true


## Removes a tag and optionally all of its children.
## e.g. removing "Character.Status" can also remove "Character.Status.Burning"
func remove_tag(tag: String, remove_children: bool = true) -> void:
	tags.erase(tag)
	if remove_children:
		var to_remove: Array[String] = []
		for t in tags:
			if t.begins_with(tag + "."):
				to_remove.append(t)
		for t in to_remove:
			tags.erase(t)

## Renames a tag. If rename_children is true, all children are updated too.
## Returns the list of tags that were changed.
func rename_tag(old_tag: String, new_tag: String, rename_children: bool) -> Array[String]:
	var changed: Array[String] = []
	if not has_tag(old_tag):
		return changed
	# Only erase the old tag itself if we are renaming children too,
	# or if it has no children. If renaming only and children exist,
	# we leave the old tag in place intentionally.
	var has_children := tags.any(func(t): return t.begins_with(old_tag + "."))
	if rename_children or not has_children:
		tags.erase(old_tag)
	tags.append(new_tag)
	changed.append(new_tag)
	if rename_children:
		var to_rename: Array[String] = []
		for t in tags:
			if t.begins_with(old_tag + "."):
				to_rename.append(t)
		for t in to_rename:
			tags.erase(t)
			var new_child := new_tag + t.substr(old_tag.length())
			tags.append(new_child)
			changed.append(new_child)
	tags.sort()
	return changed


## Returns all direct children of a parent tag.
## e.g. get_children("Character") -> ["Character.Status", "Character.Type"]
## but NOT "Character.Status.Burning" (that's a grandchild)
func get_children(parent: String) -> Array[String]:
	var result: Array[String] = []
	for t in tags:
		if not t.begins_with(parent + "."):
			continue
		var remainder := t.substr(parent.length() + 1)
		if "." not in remainder:
			result.append(t)
	return result


## Returns all root-level tags (no dots, no parent).
func get_roots() -> Array[String]:
	var result: Array[String] = []
	for t in tags:
		if "." not in t:
			result.append(t)
	return result


## Returns every ancestor tag string for a given tag.
## e.g. get_ancestors("Character.Status.Burning") -> ["Character", "Character.Status"]
func get_ancestors(tag: String) -> Array[String]:
	var parts := tag.split(".")
	var result: Array[String] = []
	for i in range(1, parts.size()):
		result.append(".".join(parts.slice(0, i)))
	return result


## Validates a tag string — only letters, numbers, underscores, and dots.
static func is_valid_tag_string(tag: String) -> bool:
	if tag.is_empty():
		return false
	if not _tag_regex:
		_tag_regex = RegEx.new()
		_tag_regex.compile("^[A-Za-z0-9_]+(\\.[A-Za-z0-9_]+)*$")
	return _tag_regex.search(tag) != null
