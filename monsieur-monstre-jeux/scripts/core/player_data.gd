class_name PlayerData
extends Node

## Manages player state including organs, gold, position, and challenge meters.

signal organs_changed
signal gold_changed
signal position_changed
signal hearts_changed

var player_id: int = 1
var organs: Dictionary = {}
var gold: int = 100
var position: int = 0
var hearts: int = 1

# Challenge meters
var stamina: float = 100.0
var oxygen: float = 100.0
var intoxication: float = 0.0
var blood_sugar: float = 100.0

# Challenge state
var heartbeat_count: int = 0
var heartbeat_check_timer: float = 0.0
var is_catching_air: bool = false
var mash_count: int = 0
var mash_timer: float = 0.0

# Organ constants (matching existing challenge system)
const ORGAN_HEART := 0
const ORGAN_LUNGS := 1
const ORGAN_ARMS := 2
const ORGAN_LEGS := 3
const ORGAN_EYES := 4
const ORGAN_PANCREAS := 5
const ORGAN_BRAIN := 6
const ORGAN_LIVER := 7
const ORGAN_KIDNEYS := 8

const ORGAN_NAMES := {
	"heart": ORGAN_HEART,
	"lungs": ORGAN_LUNGS,
	"arms": ORGAN_ARMS,
	"legs": ORGAN_LEGS,
	"eyes": ORGAN_EYES,
	"pancreas": ORGAN_PANCREAS,
	"brain": ORGAN_BRAIN,
	"liver": ORGAN_LIVER,
	"kidneys": ORGAN_KIDNEYS
}

func _init():
	_init_organs()

func _init_organs():
	organs = {
		"brain": 1,
		"heart": 1,
		"lungs": 1,
		"arms": 2,
		"legs": 2,
		"eyes": 2,
		"pancreas": 1,
		"liver": 1,
		"kidneys": 2
	}
	_update_hearts()

## Handles organ change events, updating hearts when heart organ changes.
func _on_organs_changed() -> void:
	_update_hearts()
	organs_changed.emit()

func _update_hearts() -> void:
	var old_hearts = hearts
	hearts = organs.get("heart", 1)
	if hearts != old_hearts:
		hearts_changed.emit()

func get_organ_count(organ_name: String) -> int:
	return organs.get(organ_name, 0)

func add_organ(organ_name: String, count: int = 1) -> bool:
	organs[organ_name] = organs.get(organ_name, 0) + count
	_on_organs_changed()
	return true

func remove_organ(organ_name: String, count: int = 1) -> bool:
	var current = organs.get(organ_name, 0)
	if current >= count:
		organs[organ_name] = current - count
		_on_organs_changed()
		return true
	return false

func has_organ(organ_name: String) -> bool:
	return organs.get(organ_name, 0) > 0

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit()

func remove_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit()
		return true
	return false

func set_position(space_index: int) -> void:
	position = space_index
	position_changed.emit()

# === Challenge Processing ===

## Processes heart challenge for players without hearts.
## Drains stamina and prompts for confirmation periodically.
func process_heart_challenge(delta: float) -> Dictionary:
	var hearts_count = organs.get("heart", 1)
	var result = {"penalty": 0.0, "stamina_drain": 0.0, "needs_confirmation": false}
	
	if hearts_count == 0:
		result["stamina_drain"] = 3.0 * delta
		heartbeat_check_timer += delta
		
		if heartbeat_check_timer >= 10.0:
			heartbeat_check_timer = 0.0
			result["needs_confirmation"] = true
			result["prompt"] = "Did you count to 10? Press CONFIRM"
	
	stamina = clamp(stamina - result["stamina_drain"], 0.0, 100.0)
	return result

## Processes lungs challenge including buoyancy, oxygen capacity, and catch air mechanics.
func process_lungs_challenge(delta: float) -> Dictionary:
	var lungs_count = organs.get("lungs", 1)
	var result = {
		"buoyancy_force": 0.0,
		"oxygen_capacity": 12.0,
		"oxygen_drain": 3.0,
		"needs_catch_air": false
	}
	
	match lungs_count:
		3:
			result["buoyancy_force"] = 100.0
			result["oxygen_capacity"] = 20.0
			result["oxygen_drain"] = 1.5
		2:
			result["buoyancy_force"] = 0.0
			result["oxygen_capacity"] = 12.0
			result["oxygen_drain"] = 2.0
		1:
			result["buoyancy_force"] = -80.0
			result["oxygen_capacity"] = 7.0
			result["oxygen_drain"] = 5.0
		0:
			result["buoyancy_force"] = -150.0
			result["oxygen_capacity"] = 0.0
			result["oxygen_drain"] = 8.0
	
	if oxygen > 0:
		oxygen = clamp(oxygen - result["oxygen_drain"] * delta, 0.0, 100.0)
	
	if oxygen < 20.0:
		result["needs_catch_air"] = true
	
	return result

## Processes eyes challenge affecting vision factor and screen distortion.
func process_eyes_challenge(delta: float) -> Dictionary:
	var eyes_count = organs.get("eyes", 2)
	var result = {
		"vision_factor": 1.0,
		"needs_audio_cues": false,
		"screen_distortion": 0.0
	}
	
	match eyes_count:
		2:
			result["vision_factor"] = 1.0
		1:
			result["vision_factor"] = 0.8
			result["screen_distortion"] = 0.3
		0:
			result["vision_factor"] = 0.4
			result["needs_audio_cues"] = true
			result["screen_distortion"] = 0.8
	
	return result

func get_missing_organs() -> Array:
	var missing = []
	for organ in organs:
		if organs[organ] == 0:
			missing.append(organ)
	return missing

func get_buoyancy_factor() -> float:
	var lungs = organs.get("lungs", 1)
	match lungs:
		3: return 1.5
		2: return 1.0
		1: return 0.5
		0: return 0.0
	return 1.0

func get_oxygen_capacity() -> float:
	var lungs = organs.get("lungs", 1)
	match lungs:
		3: return 20.0
		2: return 12.0
		1: return 7.0
		0: return 0.0
	return 12.0

func is_blind() -> bool:
	return organs.get("eyes", 2) == 0

## Calculates performance modifier based on missing organs.
## Returns multiplier between 0 and 1.
func get_performance_modifier() -> float:
	var modifier = 1.0
	var missing = get_missing_organs()
	
	for organ_name in missing:
		match organ_name:
			"legs":
				modifier *= 0.5
			"eyes":
				modifier *= 0.4
			"arms":
				modifier *= 0.6
			"pancreas":
				modifier *= 0.5
	
	return modifier

func reset_challenge_meters() -> void:
	stamina = 100.0
	oxygen = 100.0
	intoxication = 0.0
	blood_sugar = 100.0
	heartbeat_count = 0
	heartbeat_check_timer = 0.0
	is_catching_air = false
	mash_count = 0
	mash_timer = 0.0

# Legacy functions for compatibility with existing challenge system
func get_player(id: String) -> Dictionary:
	# Returns organ data in old format for challenge_manager compatibility
	var result = {
		"id": id,
		"score": 0,
		"money": gold,
		"organs": {}
	}
	for organ_name in organs:
		result["organs"][organ_name] = organs[organ_name] > 0
	return result

func get_player_index(id: String) -> int:
	# Simple mapping for compatibility
	if id == "p1" or id == "1":
		return 0
	return 1

func modify_money(id: String, amount: int) -> void:
	gold += amount
	gold_changed.emit()

func modify_score(id: String, points: int) -> void:
	# Score is tracked separately from gold
	pass
