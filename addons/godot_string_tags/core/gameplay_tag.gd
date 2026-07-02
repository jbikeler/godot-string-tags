@tool
class_name GameplayTag
extends Resource

@export var tag: String = ""


## Returns true if this tag matches the given string including hierarchy.
## e.g. matches("Character.Status") returns true if tag is "Character.Status.Burning"
func matches(other: String) -> bool:
	return tag == other or tag.begins_with(other + ".")


## Returns true if this tag exactly matches the given string.
func matches_exact(other: String) -> bool:
	return tag == other


## Returns a readable string of this tag.
func gt_to_string() -> String:
	return "[GameplayTag: %s]" % tag
