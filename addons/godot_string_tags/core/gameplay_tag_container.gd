@tool
class_name GameplayTagContainer
extends Resource

## Emitted when tags are added or removed at runtime.
signal tags_changed

@export var tags: Array[String] = []


# -------------------------------------------------------
# Adding & Removing
# -------------------------------------------------------

## Adds a tag to this container. Tag must exist in the registry.
## Returns false if the tag was already present or doesn't exist in the registry.
func add_tag(tag: String) -> bool:
	if has_exact(tag):
		return false
	if Engine.is_editor_hint():
		var registry : Node = Engine.get_main_loop().root.get_node_or_null("GameplayTagRegistry")
		if registry and not registry.tag_exists(tag):
			push_error("GameplayTagContainer: Tag '%s' is not registered." % tag)
			return false
	tags.append(tag)
	tags.sort()
	tags_changed.emit()
	return true


## Removes an exact tag from this container.
## Returns false if the tag wasn't present.
func remove_tag(tag: String) -> bool:
	if not has_exact(tag):
		return false
	tags.erase(tag)
	tags_changed.emit()
	return true


## Removes all tags from this container.
func clear_tags() -> void:
	if tags.is_empty():
		return
	tags.clear()
	tags_changed.emit()


# -------------------------------------------------------
# Querying
# -------------------------------------------------------

# --- Query with Strings ----------
## Exact match only — tag string must match precisely.
func has_exact(tag: String) -> bool:
	return tag in tags


## Hierarchical match — returns true if this container has the tag
## OR any descendant of it.
## e.g. has_tag("Character.Status") returns true if container has "Character.Status.Burning"
func has_tag(tag: String) -> bool:
	for t in tags:
		if t == tag or t.begins_with(tag + "."):
			return true
	return false


## Returns true if this container has every tag in listed tags (hierarchical matching).
func has_all(other_tags: Array[String]) -> bool:
	for tag in other_tags:
		if not has_tag(tag):
			return false
	return true


## Exact matches only — tag container must have all tags and they must match precisely.
func has_all_exact(other_tags: Array[String]) -> bool:
	for tag in other_tags:
		if not has_exact(tag):
			return false
	return true


## Returns true if this container has at least one tag from listed tags (hierarchical matching).
func has_any(other_tags: Array[String]) -> bool:
	for tag in other_tags:
		if has_tag(tag):
			return true
	return false


## Returns true if this container has NO tags in common with listed tags (hierarchical matching).
func has_none(other_tags: Array[String]) -> bool:
	return not has_any(other_tags)


#  --- Query with Another Container ----------
## Returns true if this container has every tag in 'other' (hierarchical matching).
func has_all_from_container(other: GameplayTagContainer) -> bool:
	for tag in other.tags:
		if not has_tag(tag):
			return false
	return true


## Returns true if this container has at least one tag from 'other' (hierarchical matching).
func has_any_from_container(other: GameplayTagContainer) -> bool:
	for tag in other.tags:
		if has_tag(tag):
			return true
	return false


## Returns true if this container has NO tags in common with 'other' (hierarchical matching).
func has_none_from_container(other: GameplayTagContainer) -> bool:
	return not has_any_from_container(other)


## Returns a new container with only the tags that match the given parent.
## e.g. filter("Character.Status") on ["Character.Status.Burning", "Ability.Fire"]
## returns a container with just ["Character.Status.Burning"]
func gt_filter(parent_tag: String) -> GameplayTagContainer:
	var result := GameplayTagContainer.new()
	for t in tags:
		if t == parent_tag or t.begins_with(parent_tag + "."):
			result.tags.append(t)
	return result


## Returns all tags in this container that are also in 'other' (exact matching).
func get_matching(other: GameplayTagContainer) -> Array[String]:
	var result: Array[String] = []
	for tag in tags:
		if other.has_exact(tag):
			result.append(tag)
	return result


# -------------------------------------------------------
# Merging
# -------------------------------------------------------

## Adds all tags from 'other' into this container.
func append_tags(other: GameplayTagContainer) -> void:
	var changed := false
	for tag in other.tags:
		if not has_exact(tag):
			tags.append(tag)
			changed = true
	if changed:
		tags.sort()
		tags_changed.emit()


## Returns a new container that is the union of this and 'other'.
func gt_merged_with(other: GameplayTagContainer) -> GameplayTagContainer:
	var result := GameplayTagContainer.new()
	result.tags = tags.duplicate()
	result.append_tags(other)
	return result


# -------------------------------------------------------
# Utility
# -------------------------------------------------------

## Returns a readable string of all tags in this container.
func gt_to_string() -> String:
	return "[GameplayTagContainer: %s]" % ", ".join(tags)
