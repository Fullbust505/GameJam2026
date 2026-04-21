class_name OrganChallengeManager
extends Node

## Manages organ-based challenges and QTE events for players.
## Tracks challenge state and processes challenge mechanics.

const OrganConst = preload("res://scripts/core/organ_constants.gd")

# Challenge state per player
var player_challenges: Dictionary = {
	1: {},
	2: {}
}

# QTE state
var active_qte: Dictionary = {
	1: null,
	2: null
}

signal challenge_triggered(player_id: int, challenge_type: String, config: Dictionary)
signal qte_completed(player_id: int, success: bool)
signal challenge_meter_updated(player_id: int, organ_id: int, value: float)

func _ready() -> void:
	pass

func start_challenges_for_player(player_id: int, player_data: PlayerData) -> void:
	var missing_organs = player_data.get_missing_organs()
	
	for organ_name in missing_organs:
		match organ_name:
			"heart":
				_init_heart_challenge(player_id, player_data)
			"lungs":
				_init_lungs_challenge(player_id, player_data)
			"eyes":
				_init_eyes_challenge(player_id, player_data)
			"pancreas":
				_init_pancreas_challenge(player_id, player_data)
			"liver":
				_init_liver_challenge(player_id, player_data)

func _init_heart_challenge(player_id: int, player_data: PlayerData) -> void:
	var hearts_count = player_data.get_organ_count("heart")
	if hearts_count == 0:
		player_challenges[player_id]["heart"] = {
			"active": true,
			"check_interval": 10.0,
			"check_timer": 0.0,
			"needs_confirmation": false
		}

func _init_lungs_challenge(player_id: int, player_data: PlayerData) -> void:
	var lungs_count = player_data.get_organ_count("lungs")
	if lungs_count < 3:
		player_challenges[player_id]["lungs"] = {
			"active": true,
			"oxygen": 100.0,
			"buoyancy_force": _get_buoyancy_force(lungs_count),
			"oxygen_drain": _get_oxygen_drain(lungs_count),
			"needs_catch_air": false,
			"catch_air_interval": 8.0,
			"catch_air_timer": 0.0
		}

func _init_eyes_challenge(player_id: int, player_data: PlayerData) -> void:
	var eyes_count = player_data.get_organ_count("eyes")
	if eyes_count == 0:
		player_challenges[player_id]["eyes"] = {
			"active": true,
			"needs_audio_cues": true,
			"screen_distortion": 1.0
		}

func _init_pancreas_challenge(player_id: int, player_data: PlayerData) -> void:
	var pancreas_count = player_data.get_organ_count("pancreas")
	if pancreas_count == 0:
		player_challenges[player_id]["pancreas"] = {
			"active": true,
			"blood_sugar": 100.0,
			"drain_rate": 4.0,
			"insulin_interval": 15.0,
			"insulin_timer": 0.0,
			"needs_insulin": false
		}

func _init_liver_challenge(player_id: int, player_data: PlayerData) -> void:
	var liver_count = player_data.get_organ_count("liver")
	if liver_count == 0:
		player_challenges[player_id]["liver"] = {
			"active": true,
			"intoxication": 0.0,
			"needs_detox": false
		}

func process_challenges(delta: float, player_id: int, player_data: PlayerData) -> Dictionary:
	var results = {"penalties": {}, "qte_triggered": null}
	
	if not player_challenges.has(player_id):
		return results
	
	var challenges = player_challenges[player_id]
	
	# Process Heart challenge
	if challenges.has("heart") and challenges["heart"]["active"]:
		var heart_result = _process_heart_challenge(delta, player_id, challenges["heart"])
		if heart_result.get("needs_confirmation"):
			results["qte_triggered"] = {"type": "heart_beat", "prompt": "Counted to 10? Press CONFIRM"}
	
	# Process Lungs challenge
	if challenges.has("lungs") and challenges["lungs"]["active"]:
		var lungs_result = _process_lungs_challenge(delta, player_id, challenges["lungs"])
		if lungs_result.get("needs_catch_air"):
			results["qte_triggered"] = {"type": "catch_air", "prompt": "Mash CATCH_AIR to breathe!"}
	
	# Process Pancreas challenge
	if challenges.has("pancreas") and challenges["pancreas"]["active"]:
		var pancreas_result = _process_pancreas_challenge(delta, player_id, challenges["pancreas"])
		if pancreas_result.get("needs_insulin"):
			results["qte_triggered"] = {"type": "insulin", "prompt": "Mash ACTION + CHALLENGE for insulin!"}
	
	return results

func _process_heart_challenge(delta: float, player_id: int, challenge: Dictionary) -> Dictionary:
	var result = {}
	challenge["check_timer"] += delta
	
	if challenge["check_timer"] >= challenge["check_interval"]:
		challenge["check_timer"] = 0.0
		challenge["needs_confirmation"] = true
		result["needs_confirmation"] = true
	
	return result

func _process_lungs_challenge(delta: float, player_id: int, challenge: Dictionary) -> Dictionary:
	var result = {}
	
	# Drain oxygen
	challenge["oxygen"] = clamp(challenge["oxygen"] - challenge["oxygen_drain"] * delta, 0.0, 100.0)
	
	# Check if need to catch air
	if challenge["oxygen"] < 20.0:
		challenge["needs_catch_air"] = true
		result["needs_catch_air"] = true
	
	challenge_meter_updated.emit(player_id, OrganConst.ORGAN_LUNGS, challenge["oxygen"])
	
	return result

func _process_pancreas_challenge(delta: float, player_id: int, challenge: Dictionary) -> Dictionary:
	var result = {}
	
	# Drain blood sugar
	challenge["blood_sugar"] = clamp(challenge["blood_sugar"] - challenge["drain_rate"] * delta, 0.0, 100.0)
	
	if challenge["blood_sugar"] < 30.0:
		challenge["needs_insulin"] = true
		result["needs_insulin"] = true
	
	challenge_meter_updated.emit(player_id, OrganConst.ORGAN_PANCREAS, challenge["blood_sugar"])
	
	return result

func _get_buoyancy_force(lungs_count: int) -> float:
	match lungs_count:
		3: return 100.0
		2: return 0.0
		1: return -80.0
		0: return -150.0
	return 0.0

func _get_oxygen_drain(lungs_count: int) -> float:
	match lungs_count:
		3: return 2.0
		2: return 3.0
		1: return 5.0
		0: return 8.0
	return 3.0

func handle_qte_input(player_id: int, qte_type: String, input_data: Dictionary) -> bool:
	if not player_challenges.has(player_id):
		return false
	
	var success = false
	
	match qte_type:
		"heart_beat":
			if input_data.get("confirmed", false):
				success = true
				# Restore some stamina
				if player_challenges[player_id].has("heart"):
					player_challenges[player_id]["heart"]["needs_confirmation"] = false
		"catch_air":
			var mash_count = input_data.get("mash_count", 0)
			var required = input_data.get("required", 10)
			if mash_count >= required:
				success = true
				if player_challenges[player_id].has("lungs"):
					player_challenges[player_id]["lungs"]["oxygen"] = 100.0
					player_challenges[player_id]["lungs"]["needs_catch_air"] = false
		"insulin":
			var mash_count = input_data.get("mash_count", 0)
			var required = input_data.get("required", 15)
			if mash_count >= required:
				success = true
				if player_challenges[player_id].has("pancreas"):
					player_challenges[player_id]["pancreas"]["blood_sugar"] = 100.0
					player_challenges[player_id]["pancreas"]["needs_insulin"] = false
	
	qte_completed.emit(player_id, success)
	return success

func clear_challenges_for_player(player_id: int) -> void:
	if player_challenges.has(player_id):
		player_challenges[player_id].clear()
	active_qte[player_id] = null

func get_challenge_info(player_id: int) -> Dictionary:
	if not player_challenges.has(player_id):
		return {}
	return player_challenges[player_id]
