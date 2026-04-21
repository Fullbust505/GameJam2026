extends Node

# Tile Event Executor for Monsieur Monstre board game
# Executes effects when players land on different tile types

# Reference to game state for player/organs management
var _game_state: Node = null
var _challenge_manager: Node = null

# Signals for tile effects
signal shop_requested(player_index: int, tile_data: Dictionary)
signal challenge_requested(player_index: int, tile_data: Dictionary)
signal challenge_completed(player_index: int, success: bool, reward_data: Dictionary)
signal event_triggered(player_index: int, event_type: String, event_data: Dictionary)
signal tile_effect_completed(player_index: int, tile_type: String, result: Dictionary)

# Random events that can occur on EVENT tiles
const RANDOM_EVENTS: Array = [
	"random_teleport",
	"money_steal",
	"free_shopping",
	"double_challenge",
	"reverse_order",
	"organ_dumpster",
	"cash_back",
	"player_curse"
]

func _ready() -> void:
	pass

# Initialize with game state reference
func setup(game_state: Node, challenge_manager: Node = null) -> void:
	_game_state = game_state
	_challenge_manager = challenge_manager

# Main entry point - execute effect for a tile
func execute_tile_effect(player_index: int, tile_type: String, tile_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"success": false, "message": "", "data": {}}
	
	# Normalize tile type string
	var normalized_type: String = tile_type.to_upper()
	
	match normalized_type:
		"CHALLENGE":
			result = _execute_challenge(player_index, tile_data)
		"STEAL":
			result = _execute_steal(player_index, tile_data)
		"SWAP":
			result = _execute_swap(player_index, tile_data)
		"SHOP":
			result = _execute_shop(player_index, tile_data)
		"BONUS":
			result = _execute_bonus(player_index, tile_data)
		"PENALTY":
			result = _execute_penalty(player_index, tile_data)
		"EVENT":
			result = _execute_event(player_index, tile_data)
		"START":
			result = _execute_start(player_index, tile_data)
		_:
			result = {"success": false, "message": "Unknown tile type: " + tile_type, "data": {}}
	
	emit_signal("tile_effect_completed", player_index, normalized_type, result)
	return result

# Execute Challenge tile - triggers minigame via ChallengeManager
func _execute_challenge(player_index: int, tile_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"success": false, "message": "Challenge initiated", "data": {}}
	
	# Get organ type from tile data
	var organ_type: int = tile_data.get("organ_type", -1)
	var stake_multiplier: float = tile_data.get("stake_multiplier", 1.0)
	
	if organ_type < 0:
		result["message"] = "Challenge failed: No organ type specified"
		return result
	
	# Emit signal to request challenge minigame
	var challenge_data: Dictionary = {
		"organ_type": organ_type,
		"stake_multiplier": stake_multiplier,
		"tile_data": tile_data
	}
	
	emit_signal("challenge_requested", player_index, challenge_data)
	result["success"] = true
	result["data"]["challenge_data"] = challenge_data
	
	return result

# Called when challenge minigame completes
func on_challenge_completed(player_index: int, success: bool, reward_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"success": success, "message": "", "data": reward_data}
	
	if not _game_state:
		result["message"] = "No game state reference"
		return result
	
	if success:
		# Player won - give reward
		var organ_type: int = reward_data.get("organ_type", -1)
		var points: int = reward_data.get("points", 10)
		var money: int = reward_data.get("money", 0)
		
		if organ_type >= 0:
			_game_state.transfer_organ(-1, player_index, organ_type)
			result["message"] = "Challenge won! Gained organ."
		else:
			_game_state.modify_score(player_index, points)
			result["message"] = "Challenge won! +" + str(points) + " points"
		
		if money > 0:
			_game_state.modify_money(player_index, money)
	else:
		# Player lost - apply penalty
		var penalty_type: String = reward_data.get("penalty_type", "organ")
		var penalty_value: int = reward_data.get("penalty_value", 1)
		
		if penalty_type == "organ":
			_game_state.transfer_organ(player_index, -1, penalty_value)
			result["message"] = "Challenge lost! Lost an organ."
		elif penalty_type == "money":
			_game_state.modify_money(player_index, -penalty_value)
			result["message"] = "Challenge lost! -" + str(penalty_value) + " money"
		else:
			_game_state.modify_score(player_index, -penalty_value)
			result["message"] = "Challenge lost! -" + str(penalty_value) + " points"
	
	emit_signal("challenge_completed", player_index, success, reward_data)
	return result

# Execute Steal tile - player steals random organ from another player
func _execute_steal(player_index: int, tile_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"success": false, "message": "", "data": {}}
	
	if not _game_state:
		result["message"] = "No game state reference"
		return result
	
	# Get success chance from tile data (default 50%)
	var success_chance: float = tile_data.get("success_chance", 0.5)
	var penalty_on_fail: bool = tile_data.get("penalty_on_fail", false)
	
	# Get other active players
	var active_players: Array = _game_state.get_active_players()
	var other_players: Array = []
	for pid in active_players:
		if pid != player_index:
			other_players.append(pid)
	
	if other_players.is_empty():
		result["message"] = "No other players to steal from"
		return result
	
	# Select random victim
	var victim_id: int = other_players[randi() % other_players.size()]
	
	# Get available organs to steal from victim
	var available_organs: Array = _game_state.get_available_organs_for_stealing(victim_id)
	
	if available_organs.is_empty():
		result["message"] = "Victim has no organs to steal"
		return result
	
	# Select random organ to steal
	var organ_to_steal: int = available_organs[randi() % available_organs.size()]
	
	# Roll for success
	var roll: float = randf()
	if roll < success_chance:
		# Success!
		if _game_state.transfer_organ(victim_id, player_index, organ_to_steal):
			var organ_name: String = _get_organ_name(organ_to_steal)
			result["success"] = true
			result["message"] = "Stole " + organ_name + " from player " + str(victim_id)
			result["data"]["victim"] = victim_id
			result["data"]["organ"] = organ_to_steal
		else:
			result["message"] = "Steal failed - organ transfer error"
	else:
		# Failed!
		result["success"] = false
		result["message"] = "Steal failed! (rolled " + str(roll) + " vs " + str(success_chance) + ")"
		
		if penalty_on_fail:
			# Lose an organ as penalty (not brain)
			var player_organs: Array = _game_state.get_available_organs_for_stealing(player_index)
			if not player_organs.is_empty():
				var penalty_organ: int = player_organs[randi() % player_organs.size()]
				_game_state.transfer_organ(player_index, victim_id, penalty_organ)
				result["message"] += " Penalty: lost " + _get_organ_name(penalty_organ)
				result["data"]["penalty_organ"] = penalty_organ
	
	return result

# Execute Swap tile - player swaps random organ with another player
func _execute_swap(player_index: int, tile_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"success": false, "message": "", "data": {}}
	
	if not _game_state:
		result["message"] = "No game state reference"
		return result
	
	var forced: bool = tile_data.get("forced", false)
	
	# Get other active players
	var active_players: Array = _game_state.get_active_players()
	var other_players: Array = []
	for pid in active_players:
		if pid != player_index:
			other_players.append(pid)
	
	if other_players.is_empty():
		result["message"] = "No other players to swap with"
		return result
	
	# Select random swap partner
	var partner_id: int = other_players[randi() % other_players.size()]
	
	# Get available organs for both players
	var player_organs: Array = _game_state.get_available_organs_for_stealing(player_index)
	var partner_organs: Array = _game_state.get_available_organs_for_stealing(partner_id)
	
	if player_organs.is_empty() or partner_organs.is_empty():
		result["message"] = "Cannot swap - one player has no organs"
		return result
	
	# Select random organs to swap
	var player_organ: int = player_organs[randi() % player_organs.size()]
	var partner_organ: int = partner_organs[randi() % partner_organs.size()]
	
	# Perform swap
	_game_state.transfer_organ(player_index, partner_id, player_organ)
	_game_state.transfer_organ(partner_id, player_index, partner_organ)
	
	result["success"] = true
	result["message"] = "Swapped " + _get_organ_name(player_organ) + " with player " + str(partner_id)
	result["data"]["partner"] = partner_id
	result["data"]["player_organ"] = player_organ
	result["data"]["partner_organ"] = partner_organ
	
	return result

# Execute Shop tile - signals that shop should be shown
func _execute_shop(player_index: int, tile_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"success": true, "message": "Shop opened", "data": {}}
	
	var price_multiplier: float = tile_data.get("price_multiplier", 1.0)
	result["data"]["price_multiplier"] = price_multiplier
	
	# Emit signal to request shop UI
	emit_signal("shop_requested", player_index, tile_data)
	
	return result

# Execute Bonus tile - player gains bonus (extra points or organ)
func _execute_bonus(player_index: int, tile_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"success": false, "message": "", "data": {}}
	
	if not _game_state:
		result["message"] = "No game state reference"
		return result
	
	var money: int = tile_data.get("money", 0)
	var score: int = tile_data.get("score", 0)
	var organ_type: int = tile_data.get("organ_type", -1)
	
	# Apply money bonus
	if money > 0:
		_game_state.modify_money(player_index, money)
		result["data"]["money"] = money
	
	# Apply score bonus
	if score > 0:
		_game_state.modify_score(player_index, score)
		result["data"]["score"] = score
	
	# Apply organ bonus (if specified)
	if organ_type >= 0:
		_game_state.transfer_organ(-1, player_index, organ_type)
		result["data"]["organ"] = organ_type
	
	result["success"] = true
	
	if money > 0 and score > 0:
		result["message"] = "Bonus! +" + str(money) + " money and +" + str(score) + " points"
	elif money > 0:
		result["message"] = "Bonus! +" + str(money) + " money"
	elif score > 0:
		result["message"] = "Bonus! +" + str(score) + " points"
	elif organ_type >= 0:
		result["message"] = "Bonus! Gained " + _get_organ_name(organ_type)
	else:
		result["message"] = "Bonus tile with no effect"
	
	return result

# Execute Penalty tile - player loses an organ or points
func _execute_penalty(player_index: int, tile_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"success": false, "message": "", "data": {}}
	
	if not _game_state:
		result["message"] = "No game state reference"
		return result
	
	var money_loss: int = tile_data.get("money_loss", 0)
	var score_loss: int = tile_data.get("score_loss", 0)
	var organ_loss: bool = tile_data.get("organ_loss", false)
	
	# Apply money penalty
	if money_loss > 0:
		_game_state.modify_money(player_index, -money_loss)
		result["data"]["money_loss"] = money_loss
	
	# Apply score penalty
	if score_loss > 0:
		_game_state.modify_score(player_index, -score_loss)
		result["data"]["score_loss"] = score_loss
	
	# Apply organ penalty (lose a random organ)
	if organ_loss:
		var available_organs: Array = _game_state.get_available_organs_for_stealing(player_index)
		if not available_organs.is_empty():
			var organ_to_lose: int = available_organs[randi() % available_organs.size()]
			_game_state.transfer_organ(player_index, -1, organ_to_lose)
			result["data"]["organ_loss"] = organ_to_lose
	
	result["success"] = true
	
	var penalty_desc: String = ""
	if money_loss > 0:
		penalty_desc += "-" + str(money_loss) + " money"
	if score_loss > 0:
		if penalty_desc:
			penalty_desc += " and "
		penalty_desc += "-" + str(score_loss) + " points"
	if organ_loss and result["data"].has("organ_loss"):
		if penalty_desc:
			penalty_desc += " and "
		penalty_desc += "lost " + _get_organ_name(result["data"]["organ_loss"])
	
	if penalty_desc:
		result["message"] = "Penalty! " + penalty_desc
	else:
		result["message"] = "Penalty tile with no effect"
	
	return result

# Execute Event tile - random event effect
func _execute_event(player_index: int, tile_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"success": false, "message": "", "data": {}}
	
	if not _game_state:
		result["message"] = "No game state reference"
		return result
	
	# Get event type from tile data or pick random
	var event_type: String = tile_data.get("event_type", "")
	if event_type.is_empty():
		event_type = RANDOM_EVENTS[randi() % RANDOM_EVENTS.size()]
	
	result["data"]["event_type"] = event_type
	
	match event_type:
		"random_teleport":
			# Teleport to random position
			var board_size: int = _game_state.get_board_size()
			var new_position: int = randi() % board_size
			# Note: Would need player_board_controller to move player
			result["data"]["new_position"] = new_position
			result["success"] = true
			result["message"] = "Random teleport to position " + str(new_position)
		
		"money_steal":
			# Steal money from all other players
			var active_players: Array = _game_state.get_active_players()
			var total_stolen: int = 0
			for pid in active_players:
				if pid != player_index:
					# Get victim money (simplified - steal random amount up to 50)
					var victim_money: int = 50  # This would need actual victim money lookup
					var steal_amount: int = randi() % 30 + 10
					_game_state.modify_money(pid, -steal_amount)
					_game_state.modify_money(player_index, steal_amount)
					total_stolen += steal_amount
			result["data"]["total_stolen"] = total_stolen
			result["success"] = true
			result["message"] = "Stole " + str(total_stolen) + " money from other players!"
		
		"free_shopping":
			# Grant free shopping (bonus money)
			var free_money: int = randi() % 50 + 50
			_game_state.modify_money(player_index, free_money)
			result["data"]["free_money"] = free_money
			result["success"] = true
			result["message"] = "Free shopping! +" + str(free_money) + " money"
		
		"double_challenge":
			# Signal that next challenge is worth double
			result["data"]["double_reward"] = true
			result["success"] = true
			result["message"] = "Next challenge is worth double!"
			emit_signal("event_triggered", player_index, event_type, result["data"])
		
		"reverse_order":
			# Reverse player turn order (would need game state support)
			result["success"] = true
			result["message"] = "Turn order reversed!"
		
		"organ_dumpster":
			# Find and gain a random organ
			var organs: Array = [1, 2, 3, 4, 5, 6, 7, 8]  # Non-brain organs
			var organ: int = organs[randi() % organs.size()]
			_game_state.transfer_organ(-1, player_index, organ)
			result["data"]["organ"] = organ
			result["success"] = true
			result["message"] = "Found " + _get_organ_name(organ) + " in dumpster!"
		
		"cash_back":
			# Get money back based on score
			var current_score: int = 0  # Would need actual score lookup
			var cash_back: int = 20
			_game_state.modify_money(player_index, cash_back)
			result["data"]["cash_back"] = cash_back
			result["success"] = true
			result["message"] = "Cash back! +" + str(cash_back) + " money"
		
		"player_curse":
			# Lose some money
			var curse_cost: int = randi() % 30 + 20
			_game_state.modify_money(player_index, -curse_cost)
			result["data"]["curse_cost"] = curse_cost
			result["success"] = true
			result["message"] = "Cursed! Lost " + str(curse_cost) + " money"
		
		_:
			result["message"] = "Unknown event: " + event_type
	
	emit_signal("event_triggered", player_index, event_type, result["data"])
	return result

# Execute Start tile - no effect (or wrap around)
func _execute_start(player_index: int, tile_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"success": true, "message": "Landed on START - wrap around!", "data": {}}
	# Start tile typically just marks the board start, no special effect
	return result

# Helper to get organ name from type
func _get_organ_name(organ_type: int) -> String:
	if _game_state and _game_state.has_method("get_organ_name"):
		return _game_state.get_organ_name(organ_type)
	
	# Fallback names
	var names: Dictionary = {
		0: "Brain",
		1: "Heart",
		2: "Lungs",
		3: "Arms",
		4: "Legs",
		5: "Eyes",
		6: "Pancreas",
		7: "Liver",
		8: "Kidneys"
	}
	return names.get(organ_type, "Unknown Organ")

# Get string tile type from enum
func get_tile_type_string(tile_type: int) -> String:
	match tile_type:
		0: return "SHOP"
		1: return "CHALLENGE"
		2: return "STEAL"
		3: return "SWAP"
		4: return "BONUS"
		5: return "PENALTY"
		6: return "EVENT"
		7: return "START"
	return "UNKNOWN"

# Get enum tile type from string
func get_tile_type_enum(tile_type_str: String) -> int:
	match tile_type_str.to_upper():
		"SHOP": return 0
		"CHALLENGE": return 1
		"STEAL": return 2
		"SWAP": return 3
		"BONUS": return 4
		"PENALTY": return 5
		"EVENT": return 6
		"START": return 7
	return -1
