class_name PlayerOrgans
extends RefCounted

## Manages a player's organ inventory with count tracking.
## Provides methods to add, remove, and query organs.

# Preload the organ constants for cross-script compatibility
const OrganConst = preload("res://scripts/core/organ_constants.gd")
# Preload organ type for data access
const OrganType = preload("res://scripts/core/organ_type.gd")

# Dictionary-based organ inventory
# Key: organ ID (int using OrganConst constants)
# Value: int (count for stackable organs, 0/1 for boolean)
var organs: Dictionary = {}

signal organs_changed(organ_id: int, new_count: int)
signal organ_added(organ_id: int, count: int)
signal organ_removed(organ_id: int, count: int)

func _init() -> void:
	_init_default_organs()

## Initializes all organs to default/max values for testing purposes.
func _init_default_organs() -> void:
	# Initialize all organs to default/max for testing
	organs[OrganConst.ORGAN_HEART] = 2
	organs[OrganConst.ORGAN_BRAIN] = 1
	organs[OrganConst.ORGAN_LUNGS] = 2
	organs[OrganConst.ORGAN_EYES] = 2
	organs[OrganConst.ORGAN_LEGS] = 2
	organs[OrganConst.ORGAN_HANDS] = 2
	organs[OrganConst.ORGAN_LIVER] = 2
	organs[OrganConst.ORGAN_KIDNEYS] = 2
	organs[OrganConst.ORGAN_ADRENAL] = 2
	organs[OrganConst.ORGAN_INTESTINE] = 2
	organs[OrganConst.ORGAN_STOMACH] = 1
	organs[OrganConst.ORGAN_PANCREAS] = 1
	organs[OrganConst.ORGAN_SPLEEN] = 1
	organs[OrganConst.ORGAN_GALLBLADDER] = 1
	organs[OrganConst.ORGAN_THYROID] = 1
	organs[OrganConst.ORGAN_SPINAL] = 1
	organs[OrganConst.ORGAN_SKIN] = 1

## Returns the current count of the specified organ.
func get_organ_count(organ_id: int) -> int:
	return organs.get(organ_id, 0)

## Sets the organ count, clamped by min/max constraints.
func set_organ_count(organ_id: int, count: int) -> void:
	var organ_data = OrganType.get_organ_data(organ_id)
	var max_count = organ_data.max_count
	var min_count = 0 if not organ_data.is_protected else 1
	count = clamp(count, min_count, max_count)
	organs[organ_id] = count
	organs_changed.emit(organ_id, count)

## Attempts to add an organ. Returns true if successful.
func add_organ(organ_id: int, count: int = 1) -> bool:
	var current = get_organ_count(organ_id)
	var organ_data = OrganType.get_organ_data(organ_id)
	if current >= organ_data.max_count:
		return false
	var new_count = mini(current + count, organ_data.max_count)
	organs[organ_id] = new_count
	organ_added.emit(organ_id, new_count)
	organs_changed.emit(organ_id, new_count)
	return true

## Attempts to remove an organ. Returns true if successful.
## Cannot remove vital or protected organs.
func remove_organ(organ_id: int, count: int = 1) -> bool:
	var organ_data = OrganType.get_organ_data(organ_id)
	if organ_data.is_vital and organ_id != OrganConst.ORGAN_HEART:
		return false
	if organ_data.is_protected:
		return false
	var current = get_organ_count(organ_id)
	if current <= 0:
		return false
	var new_count = maxi(current - count, 0)
	organs[organ_id] = new_count
	organ_removed.emit(organ_id, new_count)
	organs_changed.emit(organ_id, new_count)
	return true

## Returns true if player has at least one of the specified organ.
func has_organ(organ_id: int) -> bool:
	return get_organ_count(organ_id) > 0

## Returns array of organ IDs that the player is missing.
func get_missing_organs() -> Array:
	var missing: Array = []
	for organ_id in organs.keys():
		if organs[organ_id] <= 0:
			missing.append(organ_id)
	return missing

## Returns buoyancy factor based on lung count. Positive = float up, negative = sink.
func get_lungs_buoyancy_factor() -> float:
	var count = get_organ_count(OrganConst.ORGAN_LUNGS)
	match count:
		3: return 100.0
		2: return 0.0
		1: return -80.0
		0: return -150.0
	return 0.0

## Returns oxygen capacity based on lung count.
func get_lungs_oxygen_capacity() -> float:
	var count = get_organ_count(OrganConst.ORGAN_LUNGS)
	match count:
		3: return 20.0
		2: return 12.0
		1: return 7.0
		0: return 0.0
	return 12.0

## Returns the number of hearts the player has.
func get_heart_count() -> int:
	return get_organ_count(OrganConst.ORGAN_HEART)

## Returns true if player has no eyes (blind mode).
func is_blind() -> bool:
	return get_organ_count(OrganConst.ORGAN_EYES) == 0

## Alias for get_lungs_buoyancy_factor.
func get_buoyancy_velocity() -> float:
	return get_lungs_buoyancy_factor()

## Returns oxygen drain rate based on lung count.
func get_oxygen_drain_rate() -> float:
	var count = get_organ_count(OrganConst.ORGAN_LUNGS)
	match count:
		3: return 2.0
		2: return 3.0
		1: return 5.0
		0: return 8.0
	return 3.0
