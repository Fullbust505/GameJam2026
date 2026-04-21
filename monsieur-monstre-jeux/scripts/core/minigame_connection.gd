extends Node
## MinigameConnection - Bridge between ChallengeManager/TileEvents and actual minigame scenes
## Handles organ-to-minigame mapping, stake management, and result reporting to GameState

# Reference to GameState for organ transfers
var _game_state: Node = null

# Reference to ChallengeManager for challenge flow
var _challenge_manager: Node = null

# Current challenge context
var _current_challenge: Dictionary = {}

# Minigame scene paths mapped by organ type
# HEART → apnea (breath holding challenge)
# LUNGS → swimming (swimming challenge)
# KIDNEYS → cutting (cuisine/cutting challenge)
const MINIGAME_SCENES: Dictionary = {
	"HEART": "res://scenes/apnee_level.tscn",
	"LUNGS": "res://scenes/nage_level.tscn",
	"KIDNEYS": "res://scenes/cuisine_level.tscn",
	# Fallback mappings for related organs
	"PANCREAS": "res://scenes/cuisine_level.tscn",
	"LIVER": "res://scenes/cuisine_level.tscn",
	"EYES": "res://scenes/apnee_level.tscn",
	"ARMS": "res://scenes/nage_level.tscn",
	"LEGS": "res://scenes/nage_level.tscn",
	"BRAIN": "res://scenes/apnee_level.tscn"
}

# Signals for UI feedback
signal minigame_started(player_index: int, organ_type: String, minigame_scene: String)
signal minigame_ended(player_index: int, success: bool, result_data: Dictionary)
signal challenge_result(player_index: int, success: bool, organ_wagered: String, reward_data: Dictionary)
signal no_organs_to_wager(player_index: int)

func _ready() -> void:
	pass

## Initialize with game state and challenge manager references
func setup(game_state: Node, challenge_manager: Node = null) -> void:
	_game_state = game_state
	_challenge_manager = challenge_manager

## Start a minigame for a challenge
## player_index: The player initiating the challenge
## organ_type: String name of organ being wagered (e.g., "HEART", "LUNGS")
## stake_multiplier: Multiplier for rewards (1.0 = normal, 2.0 = double)
func start_minigame(player_index: int, organ_type: String, stake_multiplier: float = 1.0) -> bool:
	# Validate we have game state
	if not _game_state:
		push_error("MinigameConnection: No GameState reference set!")
		return false
	
	# Store challenge context
	_current_challenge = {
		"player_index": player_index,
		"organ_type": organ_type,
		"stake_multiplier": stake_multiplier,
		"minigame_scene": ""
	}
	
	# Check if player has the organ to wager
	var organ_type_int: int = _get_organ_type_int(organ_type)
	if not _game_state.can_challenge(player_index, organ_type_int):
		emit_signal("no_organs_to_wager", player_index)
		return false
	
	# Get the minigame scene for this organ type
	var minigame_scene: String = _get_minigame_scene(organ_type)
	if minigame_scene.is_empty():
		push_error("MinigameConnection: No minigame scene found for organ: " + organ_type)
		return false
	
	_current_challenge["minigame_scene"] = minigame_scene
	
	# Emit signal that minigame is starting
	emit_signal("minigame_started", player_index, organ_type, minigame_scene)
	
	# Load and instance the minigame scene
	return _load_and_start_minigame(minigame_scene)

## Get minigame scene path for organ type
func _get_minigame_scene(organ_type: String) -> String:
	# Try exact match first
	if MINIGAME_SCENES.has(organ_type):
		return MINIGAME_SCENES[organ_type]
	
	# Try case-insensitive match
	for key in MINIGAME_SCENES.keys():
		if key.to_upper() == organ_type.to_upper():
			return MINIGAME_SCENES[key]
	
	# Default fallback to apnea for unknown organs
	return MINIGAME_SCENES.get("HEART", "")

## Load and start the minigame scene
func _load_and_start_minigame(scene_path: String) -> bool:
	var scene_res = load(scene_path)
	if not scene_res:
		push_error("MinigameConnection: Failed to load scene: " + scene_path)
		return false
	
	var minigame_instance = scene_res.instantiate()
	minigame_instance.name = "ActiveMinigame"
	add_child(minigame_instance)
	
	# Pass stake information to the minigame
	var player_index: int = _current_challenge.get("player_index", -1)
	var organ_type: String = _current_challenge.get("organ_type", "")
	var stake_multiplier: float = _current_challenge.get("stake_multiplier", 1.0)
	
	# If minigame has set_stake method, call it
	if minigame_instance.has_method("set_stake"):
		minigame_instance.set_stake(player_index, organ_type, stake_multiplier)
	
	# Connect to minigame completion signal
	# Different minigames may have different signal names
	if minigame_instance.has_signal("game_ended"):
		minigame_instance.connect("game_ended", _on_minigame_game_ended)
	elif minigame_instance.has_signal("minigame_ended"):
		minigame_instance.connect("minigame_ended", _on_minigame_minigame_ended)
	elif minigame_instance.has_signal("finished"):
		minigame_instance.connect("finished", _on_minigame_finished)
	
	# Connect result signal if minigame has one
	if minigame_instance.has_signal("minigame_result"):
		minigame_instance.connect("minigame_result", _on_minigame_result_signal)
	
	# If minigame has a start method, call it
	if minigame_instance.has_method("start_game_with_stake"):
		minigame_instance.start_game_with_stake(player_index, organ_type, stake_multiplier)
	elif minigame_instance.has_method("start_game"):
		minigame_instance.start_game()
	elif minigame_instance.has_method("force_start"):
		minigame_instance.force_start()
	
	return true

## Handle minigame_result signal from minigames
func _on_minigame_result_signal(player_index: int, success: bool, result) -> void:
	# Normalize result to winner_id format
	var winner_id: int = 0
	if result is int:
		winner_id = result
	elif result is String:
		if result.to_lower() == "tie":
			winner_id = 0
		else:
			var player_num: int = result.trim_prefix("p").to_int() if result.begins_with("p") else result.to_int()
			winner_id = player_num
	elif result is bool:
		# If success, player_index wins
		winner_id = (player_index + 1) if success else 0
	
	_process_minigame_result(winner_id)

## Callback when minigame ends with winner info
func _on_minigame_game_ended(winner: String) -> void:
	_process_minigame_result(winner)

## Callback for minigame_ended signal
func _on_minigame_minigame_ended(winner_id: int) -> void:
	_process_minigame_result(winner_id)

## Callback for finished signal
func _on_minigame_finished() -> void:
	_process_minigame_result(null)

## Process the minigame result and transfer organs accordingly
func _process_minigame_result(result) -> void:
	if _current_challenge.is_empty():
		return
	
	var player_index: int = _current_challenge.get("player_index", -1)
	var organ_type: String = _current_challenge.get("organ_type", "")
	var stake_multiplier: float = _current_challenge.get("stake_multiplier", 1.0)
	var organ_type_int: int = _get_organ_type_int(organ_type)
	
	# Determine success based on result
	var success: bool = _determine_winner(result, player_index)
	
	# Clean up minigame instance
	_cleanup_minigame()
	
	# Calculate rewards/penalties
	var reward_data: Dictionary = _calculate_reward(success, organ_type_int, stake_multiplier)
	
	# Emit result signals
	emit_signal("minigame_ended", player_index, success, reward_data)
	
	# If minigame is finished, we should wait for explicit completion callback
	# This is called via on_minigame_completed

## Determine winner from minigame result
func _determine_winner(result, player_index: int) -> bool:
	# Handle different result types
	if result == null:
		return false  # Tie/no winner = loss for challenger
	
	if result is int:
		# winner_id: 0 = tie, 1 = player 1 wins, 2 = player 2 wins
		if result == 0:
			return false  # Tie = loss for challenger
		# Player index is 0-based, winner_id is 1-based
		return (result - 1) == player_index
	elif result is String:
		# winner string like "p1", "p2", "tie"
		if result.to_lower() == "tie":
			return false
		# Extract player number from string
		var player_num: int = result.trim_prefix("p").to_int() if result.begins_with("p") else result.to_int()
		return player_num == (player_index + 1)
	elif result is bool:
		return result
	
	return false

## Calculate reward based on win/loss
func _calculate_reward(success: bool, organ_type_int: int, stake_multiplier: float) -> Dictionary:
	var reward_data: Dictionary = {
		"organ_type": organ_type_int,
		"success": success
	}
	
	if success:
		# Win: Transfer organ from pool/bank (or opponent if applicable)
		# Base reward is 1 organ, multiplied by stake
		var bonus_organs: int = int(stake_multiplier)
		reward_data["bonus_organs"] = bonus_organs
		reward_data["points"] = 10 * stake_multiplier
		reward_data["message"] = "Challenge Won! +" + str(bonus_organs) + " organ(s)"
	else:
		# Loss: Lose the wagered organ
		reward_data["penalty_type"] = "organ"
		reward_data["penalty_value"] = organ_type_int
		reward_data["message"] = "Challenge Lost! Lost wagered organ"
	
	return reward_data

## Called when minigame completion is confirmed
## success: Whether the player won the minigame
## organ_wagered: The organ type string that was wagered
func on_minigame_completed(player_index: int, success: bool, organ_wagered: String) -> Dictionary:
	if not _game_state:
		return {"success": false, "message": "No GameState reference"}
	
	var organ_type_int: int = _get_organ_type_int(organ_wagered)
	var result_data: Dictionary = {"success": success, "organ_wagered": organ_wagered}
	
	if success:
		# Player won - award organ from bank/pool (no transfer needed since it's a challenge win)
		# The player wagered and won, so they keep their organ plus get another
		var stake_multiplier: float = _current_challenge.get("stake_multiplier", 1.0) if not _current_challenge.is_empty() else 1.0
		var bonus_count: int = int(max(1, stake_multiplier))
		
		# Transfer organ from "bank" (player_index = -1 means bank/none)
		_game_state.transfer_organ(-1, player_index, organ_type_int)
		
		# Award bonus organs based on multiplier
		for i in range(bonus_count - 1):
			_game_state.transfer_organ(-1, player_index, organ_type_int)
		
		result_data["message"] = "Won " + organ_wagered + "! Bonus: x" + str(stake_multiplier)
		result_data["organ_transferred"] = true
	else:
		# Player lost - lose the wagered organ
		_game_state.transfer_organ(player_index, -1, organ_type_int)
		result_data["message"] = "Lost " + organ_wagered + "!"
		result_data["organ_transferred"] = true
	
	# Emit challenge result signal
	emit_signal("challenge_result", player_index, success, organ_wagered, result_data)
	
	# Clear current challenge
	_current_challenge.clear()
	
	return result_data

## Handle tie/draw case - organ stays with current owner
func on_minigame_tied(player_index: int, organ_wagered: String) -> Dictionary:
	var result_data: Dictionary = {
		"success": false,  # Tied game - no winner
		"message": "Challenge Tied! " + organ_wagered + " stays with current owner",
		"organ_stayed": true
	}
	
	emit_signal("challenge_result", player_index, false, organ_wagered, result_data)
	_current_challenge.clear()
	
	return result_data

## Handle case where defender has no organs to wager
func handle_no_defender_organs(challenger_index: int, organ_type: String) -> Dictionary:
	# If defender can't wager, challenger automatically wins
	var organ_type_int: int = _get_organ_type_int(organ_type)
	
	# Award organ to challenger from bank
	if _game_state:
		_game_state.transfer_organ(-1, challenger_index, organ_type_int)
	
	var result_data: Dictionary = {
		"success": true,
		"message": "Defender had no organs! Won " + organ_type,
		"auto_win": true
	}
	
	emit_signal("challenge_result", challenger_index, true, organ_type, result_data)
	
	return result_data

## Clean up minigame instance
func _cleanup_minigame() -> void:
	var minigame = get_node_or_null("ActiveMinigame")
	if minigame:
		minigame.queue_free()

## Convert organ type string to integer
func _get_organ_type_int(organ_type: String) -> int:
	# Try GameState OrganType enum first
	if _game_state and _game_state.has_method("get_organ_type_by_name"):
		return _game_state.get_organ_type_by_name(organ_type)
	
	# Manual mapping based on game_state.gd OrganType enum
	var organ_map: Dictionary = {
		"BRAIN": 0,
		"HEART": 1,
		"LUNGS": 2,
		"ARMS": 3,
		"LEGS": 4,
		"EYES": 5,
		"PANCREAS": 6,
		"LIVER": 7,
		"KIDNEYS": 8
	}
	
	var upper_name = organ_type.to_upper()
	if organ_map.has(upper_name):
		return organ_map[upper_name]
	
	# Try reverse lookup
	for key in organ_map.keys():
		if key.to_lower() == organ_type.to_lower():
			return organ_map[key]
	
	return -1

## Get organ name from type int
func _get_organ_type_string(organ_type_int: int) -> String:
	if _game_state and _game_state.has_method("get_organ_name"):
		return _game_state.get_organ_name(organ_type_int)
	
	var organ_names: Array = ["BRAIN", "HEART", "LUNGS", "ARMS", "LEGS", "EYES", "PANCREAS", "LIVER", "KIDNEYS"]
	if organ_type_int >= 0 and organ_type_int < organ_names.size():
		return organ_names[organ_type_int]
	
	return "UNKNOWN"

## Get available organs for wagering from a player
func get_available_organs(player_index: int) -> Array:
	if not _game_state:
		return []
	
	return _game_state.get_available_organs_for_stealing(player_index)

## Get current challenge info
func get_current_challenge() -> Dictionary:
	return _current_challenge.duplicate(true)

## Cancel current challenge
func cancel_challenge() -> void:
	_cleanup_minigame()
	_current_challenge.clear()

## Connect to tile_event_executor challenge_requested signal
## Call this to automatically launch minigames when challenge tiles are landed on
func connect_to_tile_event_executor(tile_event_executor: Node) -> void:
	if tile_event_executor.has_signal("challenge_requested"):
		tile_event_executor.connect("challenge_requested", _on_tile_challenge_requested)

func _on_tile_challenge_requested(player_index: int, challenge_data: Dictionary) -> void:
	var organ_type: String = challenge_data.get("organ_type", "")
	var stake_multiplier: float = challenge_data.get("stake_multiplier", 1.0)
	
	if not organ_type.is_empty():
		start_minigame(player_index, organ_type, stake_multiplier)

## Get minigame scene path for organ type (public method)
func get_minigame_for_organ(organ_type: String) -> String:
	return _get_minigame_scene(organ_type)

## Check if player has organs available for challenge
func player_can_challenge(player_index: int, organ_type: String) -> bool:
	var organ_type_int: int = _get_organ_type_int(organ_type)
	if _game_state:
		return _game_state.can_challenge(player_index, organ_type_int)
	return false