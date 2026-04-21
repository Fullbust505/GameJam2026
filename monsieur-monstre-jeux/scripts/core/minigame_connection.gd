extends Node
## MinigameConnection - Bridge between ChallengeManager/TileEvents and actual minigame scenes
## Handles pool-based minigame selection, stake management, and result reporting to GameState

# Reference to GameState for organ transfers
var _game_state: Node = null

# Reference to ChallengeManager for challenge flow
var _challenge_manager: Node = null

# Current challenge context
var _current_challenge: Dictionary = {}

# Pool-based minigame selection system
# Pool of minigames that randomly depletes and restocks
var _minigame_pool: Array = []
var _all_available_minigames: Array = []

## MINIGAME POOL - List of all available minigames (6 total)
## These are randomly selected, independent of organ type
const MINIGAME_SCENES: Array = [
	"res://scenes/cuisine_level.tscn",       # Cutting minigame
	"res://scenes/nage_level.tscn",          # Swimming minigame
	"res://scenes/apnea_survival_level.tscn", # Underwater survival minigame
	"res://scenes/cut_P1.tscn",              # Player 1 cutting minigame
	"res://scenes/cut_P2.tscn",              # Player 2 cutting minigame
	"res://scenes/nage_P1.tscn",             # Player 1 swimming minigame (placeholder)
	"res://scenes/drinking_level.tscn"     # Drinking minigame
]

# Signals for UI feedback
signal minigame_started(player_index: int, organ_type: String, minigame_scene: String)
signal minigame_ended(player_index: int, success: bool, result_data: Dictionary)
signal challenge_result(player_index: int, success: bool, organ_wagered: String, reward_data: Dictionary)
signal no_organs_to_wager(player_index: int)
# Signal emitted when winner needs to choose organ to steal
signal organ_selection_required(winner_id: int, loser_id: int, available_organs: Array)

func _ready() -> void:
	_initialize_minigame_pool()

## Initialize the minigame pool with all available minigames
func _initialize_minigame_pool() -> void:
	_all_available_minigames = MINIGAME_SCENES.duplicate()
	_restock_pool()

## Get a random minigame from the pool
## If pool is empty, restock it first
func _get_random_minigame() -> String:
	if _minigame_pool.is_empty():
		_restock_pool()
	return _minigame_pool.pop_front()

## Restock the pool by shuffling all available minigames
func _restock_pool() -> void:
	_minigame_pool = _all_available_minigames.duplicate()
	_minigame_pool.shuffle()

## Get current pool status (for debugging/UI)
func get_pool_status() -> Dictionary:
	return {
		"pool_size": _minigame_pool.size(),
		"all_available": _all_available_minigames.size(),
		"pool": _minigame_pool.duplicate()
	}

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
	
	# Get a random minigame from the pool (independent of organ type)
	var minigame_scene: String = _get_random_minigame()
	if minigame_scene.is_empty():
		push_error("MinigameConnection: Minigame pool is empty!")
		return false
	
	_current_challenge["minigame_scene"] = minigame_scene
	
	# Emit signal that minigame is starting
	emit_signal("minigame_started", player_index, organ_type, minigame_scene)
	
	# Load and instance the minigame scene
	return _load_and_start_minigame(minigame_scene)

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

## Process the minigame result and initiate organ stealing
func _process_minigame_result(result) -> void:
	if _current_challenge.is_empty():
		return
	
	var player_index: int = _current_challenge.get("player_index", -1)
	var organ_type: String = _current_challenge.get("organ_type", "")
	var stake_multiplier: float = _current_challenge.get("stake_multiplier", 1.0)
	var organ_type_int: int = _get_organ_type_int(organ_type)
	
	# Determine winner
	var winner_id: int = _determine_winner_id(result, player_index)
	var loser_id: int = _get_loser_id(winner_id, player_index)
	var is_tie: bool = (winner_id == 0)
	
	# Clean up minigame instance
	_cleanup_minigame()
	
	# Calculate rewards/penalties
	var success: bool = (winner_id == player_index + 1)
	var reward_data: Dictionary = _calculate_reward(success, organ_type_int, stake_multiplier)
	
	# Emit result signals
	emit_signal("minigame_ended", player_index, success, reward_data)
	
	# Store challenge result for organ selection phase
	_current_challenge["winner_id"] = winner_id
	_current_challenge["loser_id"] = loser_id
	_current_challenge["is_tie"] = is_tie
	_current_challenge["result_data"] = reward_data

## Determine winner ID from minigame result
func _determine_winner_id(result, player_index: int) -> int:
	if result == null:
		return 0  # Tie/no winner
	
	if result is bool:
		return (player_index + 1) if result else 0
	elif result is int:
		return result
	elif result is String:
		if result.to_lower() == "tie":
			return 0
		var player_num: int = result.trim_prefix("p").to_int() if result.begins_with("p") else result.to_int()
		return player_num
	
	return 0

## Get loser ID based on winner
func _get_loser_id(winner_id: int, challenger_index: int) -> int:
	if winner_id == 0:
		return -1  # Tie - no loser
	
	# In 2-player game, if winner is player 1, loser is player 2 and vice versa
	var challenger_id: int = challenger_index + 1
	if winner_id == challenger_id:
		# Winner is the challenger - loser is the opponent (player 2 if challenger is 1, player 1 if challenger is 2)
		return 2 if challenger_id == 1 else 1
	else:
		# Winner is the opponent - loser is the challenger
		return challenger_id

## Calculate reward based on win/loss
func _calculate_reward(success: bool, organ_type_int: int, stake_multiplier: float) -> Dictionary:
	var reward_data: Dictionary = {
		"organ_type": organ_type_int,
		"success": success
	}
	
	if success:
		var bonus_organs: int = int(stake_multiplier)
		reward_data["bonus_organs"] = bonus_organs
		reward_data["points"] = 10 * stake_multiplier
		reward_data["message"] = "Challenge Won! +" + str(bonus_organs) + " organ(s)"
	else:
		reward_data["penalty_type"] = "organ"
		reward_data["penalty_value"] = organ_type_int
		reward_data["message"] = "Challenge Lost! Lost wagered organ"
	
	return reward_data

## Called when minigame completion is confirmed - handles organ transfer
## winner_id: The winning player's ID (1 or 2), 0 for tie
## loser_id: The losing player's ID (1 or 2), -1 for tie
func on_minigame_completed(winner_id: int, loser_id: int) -> Dictionary:
	if not _game_state:
		return {"success": false, "message": "No GameState reference"}
	
	var result_data: Dictionary = {"success": false, "winner_id": winner_id, "loser_id": loser_id}
	
	# Handle tie case
	if winner_id == 0:
		result_data["message"] = "Challenge Tied! Organs stay with current owners"
		result_data["organ_stayed"] = true
		_current_challenge.clear()
		return result_data
	
	# Winner chooses organ to steal from loser
	var winner_index: int = winner_id - 1
	var loser_index: int = loser_id - 1
	
	# Get organs available for stealing from loser
	var available_organs: Array = _game_state.get_available_organs_for_stealing(loser_index)
	
	if available_organs.is_empty():
		# Loser has no stealable organs - winner auto-wins
		result_data["message"] = "Loser has no organs! Winner takes organ from bank"
		result_data["auto_win"] = true
		var organ_wagered: String = _current_challenge.get("organ_type", "")
		var organ_type_int: int = _get_organ_type_int(organ_wagered)
		_game_state.transfer_organ(-1, winner_index, organ_type_int)
	else:
		# Emit signal to request organ selection from winner
		emit_signal("organ_selection_required", winner_id, loser_id, available_organs)
		result_data["message"] = "Winner must choose organ to steal"
		result_data["waiting_for_selection"] = true
	
	_current_challenge["pending_winner_choice"] = true
	return result_data

## Called when winner selects organ to steal
## winner_id: The winning player's ID (1 or 2)
## loser_id: The losing player's ID (1 or 2)
## organ_type_int: The organ type to steal
func on_organ_selected(winner_id: int, loser_id: int, organ_type_int: int) -> Dictionary:
	if not _game_state:
		return {"success": false, "message": "No GameState reference"}
	
	var winner_index: int = winner_id - 1
	var loser_index: int = loser_id - 1
	
	# Transfer organ from loser to winner
	var success: bool = _game_state.transfer_organ(loser_index, winner_index, organ_type_int)
	
	var organ_name: String = _get_organ_type_string(organ_type_int)
	var result_data: Dictionary = {
		"success": success,
		"organ_stolen": organ_name,
		"winner_id": winner_id,
		"loser_id": loser_id
	}
	
	if success:
		result_data["message"] = "Winner stole " + organ_name + "!"
		emit_signal("challenge_result", winner_index, true, organ_name, result_data)
	else:
		result_data["message"] = "Failed to steal " + organ_name
		emit_signal("challenge_result", winner_index, false, organ_name, result_data)
	
	# Clear current challenge
	_current_challenge.clear()
	
	return result_data

## Called when minigame completion is confirmed (legacy support)
## success: Whether the player won the minigame
## organ_wagered: The organ type string that was wagered
func on_minigame_completed_legacy(player_index: int, success: bool, organ_wagered: String) -> Dictionary:
	if not _game_state:
		return {"success": false, "message": "No GameState reference"}
	
	var organ_type_int: int = _get_organ_type_int(organ_wagered)
	var result_data: Dictionary = {"success": success, "organ_wagered": organ_wagered}
	
	if success:
		# Player won - award organ from bank/pool
		var stake_multiplier: float = _current_challenge.get("stake_multiplier", 1.0) if not _current_challenge.is_empty() else 1.0
		var bonus_count: int = int(max(1, stake_multiplier))
		
		# Transfer organ from "bank"
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
	
	emit_signal("challenge_result", player_index, success, organ_wagered, result_data)
	_current_challenge.clear()
	
	return result_data

## Handle tie/draw case - organ stays with current owner
func on_minigame_tied(player_index: int, organ_wagered: String) -> Dictionary:
	var result_data: Dictionary = {
		"success": false,
		"message": "Challenge Tied! " + organ_wagered + " stays with current owner",
		"organ_stayed": true
	}
	
	emit_signal("challenge_result", player_index, false, organ_wagered, result_data)
	_current_challenge.clear()
	
	return result_data

## Handle case where defender has no organs to wager
func handle_no_defender_organs(challenger_index: int, organ_type: String) -> Dictionary:
	var organ_type_int: int = _get_organ_type_int(organ_type)
	
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
	if _game_state and _game_state.has_method("get_organ_type_by_name"):
		return _game_state.get_organ_type_by_name(organ_type)
	
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
func connect_to_tile_event_executor(tile_event_executor: Node) -> void:
	if tile_event_executor.has_signal("challenge_requested"):
		tile_event_executor.connect("challenge_requested", _on_tile_challenge_requested)

func _on_tile_challenge_requested(player_index: int, challenge_data: Dictionary) -> void:
	var organ_type: String = challenge_data.get("organ_type", "")
	var stake_multiplier: float = challenge_data.get("stake_multiplier", 1.0)
	
	if not organ_type.is_empty():
		start_minigame(player_index, organ_type, stake_multiplier)

## Get a random minigame scene path (public method for UI preview)
func get_random_minigame_scene() -> String:
	return _get_random_minigame()

## Check if player has organs available for challenge
func player_can_challenge(player_index: int, organ_type: String) -> bool:
	var organ_type_int: int = _get_organ_type_int(organ_type)
	if _game_state:
		return _game_state.can_challenge(player_index, organ_type_int)
	return false
