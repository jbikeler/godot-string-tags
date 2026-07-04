@tool
class_name GameplayTag
extends Resource


@export var tag: String = ""


## Returns true if this tag matches the given string including hierarchy.
## e.g. matches("Character.Status") returns true if tag is "Character.Status.Burning"
func includes(other: String) -> bool:
	return tag == other or tag.begins_with(other + ".")


## Returns true if this tag exactly matches the given string.
func matches(other: String) -> bool:
	return tag == other


## Returns true if this tag matches the given gameplay tag including hierarchy.
## Ex:
## var example_gt_tag_1 : GameplayTag = Character.Status
## var example_gt_tag_2 : GameplayTag = Character.Status.Burning
## example_gt_tag_1.matches(example_gt_tag_2) returns true
func matches_gt(other: GameplayTag) -> bool:
	return tag == other.tag or tag.begins_with(other.tag + ".")


## Returns true if this tag exactly matches the given string.
## Ex:
## var example_gt_tag_1 : GameplayTag = Character.Status
## var example_gt_tag_2 : GameplayTag = Character.Status.Burning
## example_gt_tag_1.matches(example_gt_tag_2) returns false
func matches_gt_exact(other: GameplayTag) -> bool:
	return tag == other.tag


## Returns a readable string of this tag.
func tag_to_string() -> String:
	return "[GameplayTag: %s]" % tag
