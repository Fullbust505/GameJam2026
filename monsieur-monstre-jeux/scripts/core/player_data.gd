class_name PlayerData
extends Node

## Manages player state including organs, gold, position, and challenge meters.

const OrganConst = preload("res://scripts/core/organ_constants.gd")
const OrganType = preload("res://scripts/core/organ_type.gd")

signal organs_changed
signal gold_changed
signal position_changed
signal hearts_changed

var player_id: int = 1
var organs: PlayerOrgans
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

func _init(p_id: int = 1):
	player_id = p_id
	organs = PlayerOrgans.new()
	hearts = organs.get_heart_count()

func _ready() -> void:
	organs.organs_changed.connect(_on_organs_changed)

## Handles organ change events, updating hearts when heart organ changes.
func _on_organs_changed(organ_id: int, count: int) -> void:
	if organ_id == OrganConst.ORGAN_HEART:
		hearts = count
		hearts_changed.emit()
	organs_changed.emit()

func get_organ_count(organ_id: int) -> int:
	return organs.get_organ_count(organ_id)

func add_organ(organ_id: int, count: int = 1) -> bool:
	return organs.add_organ(organ_id, count)

func remove_organ(organ_id: int, count: int = 1) -> bool:
	return organs.remove_organ(organ_id, count)

func has_organ(organ_id: int) -> bool:
	return organs.has_organ(organ_id)

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
	var hearts_count = organs.get_heart_count()
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
	var lungs_count = organs.get_organ_count(OrganConst.ORGAN_LUNGS)
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
	var eyes_count = organs.get_organ_count(OrganConst.ORGAN_EYES)
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
	return organs.get_missing_organs()

func get_buoyancy_factor() -> float:
	return organs.get_lungs_buoyancy_factor()

func get_oxygen_capacity() -> float:
	return organs.get_lungs_oxygen_capacity()

func is_blind() -> bool:
	return organs.is_blind()

## Calculates performance modifier based on missing organs.
## Returns multiplier between 0 and 1.
func get_performance_modifier() -> float:
	var modifier = 1.0
	var missing = get_missing_organs()
	
	for organ_id in missing:
		match organ_id:
			OrganConst.ORGAN_LEGS:
				modifier *= 0.5
			OrganConst.ORGAN_EYES:
				modifier *= 0.4
			OrganConst.ORGAN_HANDS:
				modifier *= 0.6
			OrganConst.ORGAN_STOMACH:
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
