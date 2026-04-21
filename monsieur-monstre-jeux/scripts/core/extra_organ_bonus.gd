extends Node
## Extra Organ Bonus System - Grants special abilities to players with extra organs
## Players who have more than their base organ count unlock powerful bonus mechanics

# Reference to GameState
var _game_state: Node = null

# Track bonus activations per turn
var _bonus_activated_this_turn: Dictionary = {}  # player_index -> [organ_type, ...]

# Base organ counts (from game_state.gd PlayerState._init_organs)
const BASE_ORGAN_COUNTS: Dictionary = {
	0: 1,  # BRAIN
	1: 1,  # HEART
	2: 1,  # LUNGS
	3: 2,  # ARMS
	4: 2,  # LEGS
	5: 2,  # EYES
	6: 1,  # PANCREAS
	7: 1,  # LIVER
	8: 2   # KIDNEYS
}

# Bonus definitions for each organ type
# Each bonus has: name, description, effect_type, effect_value
const ORGAN_BONUSES: Dictionary = {
	0: {  # BRAIN
		"name": "Genius Boost",
		"description": "Score bonus or free shop visit",
		"effect_type": "score_multiplier",
		"effect_value": 1.5
	},
	1: {  # HEART
		"name": "Second Wind",
		"description": "Survive one lost challenge per turn",
		"effect_type": "survivor",
		"effect_value": 1
	},
	2: {  # LUNGS
		"name": "Oxygen Reserve",
		"description": "Extended breath in apnea challenges",
		"effect_type": "breath_bonus",
		"effect_value": 3.0  # 3x breath time
	},
	3: {  # ARMS
		"name": "Power Grip",
		"description": "Double button mash power in challenges",
		"effect_type": "mash_multiplier",
		"effect_value": 2.0
	},
	4: {  # LEGS
		"name": "Sprint",
		"description": "Extra movement speed / skip tiles",
		"effect_type": "movement_bonus",
		"effect_value": 1
	},
	5: {  # EYES
		"name": "Precognition",
		"description": "See opponent's next roll",
		"effect_type": "peek_dice",
		"effect_value": 1
	},
	6: {  # PANCREAS
		"name": "Sugar Rush",
		"description": "Money multiplier from challenges",
		"effect_type": "money_multiplier",
		"effect_value": 1.5
	},
	7: {  # LIVER
		"name": "Detox",
		"description": "Reduce penalty costs by 50%",
		"effect_type": "damage_reduction",
		"effect_value": 0.5
	},
	8: {  # KIDNEYS
		"name": "Golden Touch",
		"description": "Earn bonus money on each tile",
		"effect_type": "income_bonus",
		"effect_value": 5
	}
}

# Signal emitted when a bonus is activated
signal bonus_activated(player_index: int, organ_type: int, effect: Dictionary)
signal bonus_available(player_index: int, available_bonuses: Array)

## Initialize with game state reference
func setup(game_state: Node) -> void:
	_game_state = game_state

## Check if player has any extra organs (beyond base count)
## Returns array of organ types that exceed base count
func check_extra_organs(player_index: int) -> Array:
	var extra_organs: Array = []
	
	if not _game_state:
		return extra_organs
	
	var player = _game_state.get_current_player()
	if player and player.player_id != player_index:
		# Try to get specific player
		if player_index < _game_state.players.size():
			player = _game_state.players[player_index]
		else:
			return extra_organs
	
	if not player:
		return extra_organs
	
	for organ_type in BASE_ORGAN_COUNTS.keys():
		var current_count: int = player.get_organ_count(organ_type)
		var base_count: int = BASE_ORGAN_COUNTS.get(organ_type, 1)
		
		if current_count > base_count:
			extra_organs.append(organ_type)
	
	return extra_organs

## Get the bonus effect for a specific organ type
func get_bonus_for_organ(organ_type: int) -> Dictionary:
	if ORGAN_BONUSES.has(organ_type):
		return ORGAN_BONUSES[organ_type]
	return {}

## Check if a bonus can be activated (once per turn limit)
func can_activate_bonus(player_index: int, organ_type: int) -> bool:
	# Check if already activated this turn
	var activated_list: Array = _bonus_activated_this_turn.get(player_index, [])
	
	# For now, each bonus can only be used once per turn
	# Some effects might have limited uses per bonus
	var bonus = get_bonus_for_organ(organ_type)
	var effect_value = bonus.get("effect_value", 1)
	
	if effect_value <= 0:
		return false
	
	# Check if this specific bonus was already used
	if organ_type in activated_list:
		return false
	
	return true

## Activate a bonus for a player
## Returns true if successful, false otherwise
func activate_bonus(player_index: int, organ_type: int) -> bool:
	if not _game_state:
		push_error("ExtraOrganBonus: No GameState reference!")
		return false
	
	# Verify player has extra organs
	var extra_organs = check_extra_organs(player_index)
	if organ_type not in extra_organs:
		push_warning("ExtraOrganBonus: Player " + str(player_index) + " has no extra " + str(organ_type))
		return false
	
	# Check if can activate
	if not can_activate_bonus(player_index, organ_type):
		push_warning("ExtraOrganBonus: Bonus already activated this turn")
		return false
	
	# Get the bonus effect
	var bonus = get_bonus_for_organ(organ_type)
	if bonus.is_empty():
		push_error("ExtraOrganBonus: No bonus defined for organ type " + str(organ_type))
		return false
	
	# Track activation
	if not _bonus_activated_this_turn.has(player_index):
		_bonus_activated_this_turn[player_index] = []
	_bonus_activated_this_turn[player_index].append(organ_type)
	
	# Apply the bonus effect based on type
	_apply_bonus_effect(player_index, organ_type, bonus)
	
	# Emit signal
	emit_signal("bonus_activated", player_index, organ_type, bonus)
	
	return true

## Apply the specific bonus effect
func _apply_bonus_effect(player_index: int, organ_type: int, bonus: Dictionary) -> void:
	var effect_type = bonus.get("effect_type", "")
	var effect_value = bonus.get("effect_value", 1)
	
	match effect_type:
		"score_multiplier":
			# BRAIN bonus: Multiply next score gain
			_apply_score_multiplier(player_index, effect_value)
		"survivor":
			# HEART bonus: Mark player as surviving next loss
			_apply_survivor_bonus(player_index)
		"breath_bonus":
			# LUNGS bonus: Set breath multiplier for apnea
			_apply_breath_bonus(player_index, effect_value)
		"mash_multiplier":
			# ARMS bonus: Double mash power
			_apply_mash_multiplier(player_index, effect_value)
		"movement_bonus":
			# LEGS bonus: Add extra movement
			_apply_movement_bonus(player_index, effect_value)
		"peek_dice":
			# EYES bonus: Reveal opponent's dice
			_apply_peek_dice(player_index)
		"money_multiplier":
			# PANCREAS bonus: Multiply money gains
			_apply_money_multiplier(player_index, effect_value)
		"damage_reduction":
			# LIVER bonus: Reduce penalties
			_apply_damage_reduction(player_index, effect_value)
		"income_bonus":
			# KIDNEYS bonus: Bonus income per tile
			_apply_income_bonus(player_index, effect_value)

## BRAIN: Score multiplier
func _apply_score_multiplier(player_index: int, multiplier: float) -> void:
	if _game_state:
		var bonus_score = int(20 * multiplier)  # Base 20 points * multiplier
		_game_state.modify_score(player_index, bonus_score)

## HEART: Survivor bonus - player survives one loss
var _survivor_active: Dictionary = {}

func _apply_survivor_bonus(player_index: int) -> void:
	_survivor_active[player_index] = true

func is_survivor_active(player_index: int) -> bool:
	return _survivor_active.get(player_index, false)

func consume_survivor(player_index: int) -> bool:
	if _survivor_active.get(player_index, false):
		_survivor_active[player_index] = false
		return true
	return false

## LUNGS: Breath bonus for apnea
var _breath_multiplier: Dictionary = {}

func _apply_breath_bonus(player_index: int, multiplier: float) -> void:
	_breath_multiplier[player_index] = multiplier

func get_breath_multiplier(player_index: int) -> float:
	return _breath_multiplier.get(player_index, 1.0)

## ARMS: Mash multiplier for button mashing challenges
var _mash_multiplier: Dictionary = {}

func _apply_mash_multiplier(player_index: int, multiplier: float) -> void:
	_mash_multiplier[player_index] = multiplier

func get_mash_multiplier(player_index: int) -> float:
	return _mash_multiplier.get(player_index, 1.0)

## LEGS: Movement bonus
var _movement_bonus: Dictionary = {}

func _apply_movement_bonus(player_index: int, tiles: int) -> void:
	if _game_state:
		var player = _game_state.players[player_index] if player_index < _game_state.players.size() else null
		if player:
			player.position = (player.position + tiles) % _game_state.board_size
			_game_state.emit_signal("tile_landed", player_index, player.position)

## EYES: Peek at opponent's next roll
var _peek_active: Dictionary = {}

func _apply_peek_dice(player_index: int) -> void:
	_peek_active[player_index] = true

func is_peek_active(player_index: int) -> bool:
	return _peek_active.get(player_index, false)

func consume_peek(player_index: int) -> bool:
	if _peek_active.get(player_index, false):
		_peek_active[player_index] = false
		return true
	return false

func get_opponent_next_roll() -> int:
	# Returns the next dice roll (generated when peeking)
	if _game_state:
		return _game_state.roll_dice()
	return randi() % 6 + 1

## PANCREAS: Money multiplier
var _money_multiplier: Dictionary = {}

func _apply_money_multiplier(player_index: int, multiplier: float) -> void:
	_money_multiplier[player_index] = multiplier

func get_money_multiplier(player_index: int) -> float:
	return _money_multiplier.get(player_index, 1.0)

## LIVER: Damage reduction
var _damage_reduction: Dictionary = {}

func _apply_damage_reduction(player_index: int, reduction: float) -> void:
	_damage_reduction[player_index] = reduction

func get_damage_reduction(player_index: int) -> float:
	return _damage_reduction.get(player_index, 1.0)

func apply_reduced_penalty(player_index: int, original_penalty: int) -> int:
	var reduction = get_damage_reduction(player_index)
	return int(original_penalty * reduction)

## KIDNEYS: Income bonus
var _income_bonus: Dictionary = {}

func _apply_income_bonus(player_index: int, bonus: int) -> void:
	_income_bonus[player_index] = bonus

func get_income_bonus(player_index: int) -> int:
	return _income_bonus.get(player_index, 0)

func collect_income_bonus(player_index: int) -> void:
	var bonus = get_income_bonus(player_index)
	if bonus > 0 and _game_state:
		_game_state.modify_money(player_index, bonus)

## Reset bonuses at the start of a new turn
func on_turn_started(player_index: int) -> void:
	# Clear tracking for this player
	_bonus_activated_this_turn[player_index] = []
	
	# Notify player of available bonuses
	var available = check_extra_organs(player_index)
	if not available.is_empty():
		emit_signal("bonus_available", player_index, available)

## Get all available bonuses for a player as a readable array
func get_available_bonuses_info(player_index: int) -> Array:
	var extra_organs = check_extra_organs(player_index)
	var bonus_info: Array = []
	
	for organ_type in extra_organs:
		var bonus = get_bonus_for_organ(organ_type)
		if not bonus.is_empty():
			bonus_info.append({
				"organ_type": organ_type,
				"organ_name": _get_organ_name(organ_type),
				"name": bonus.get("name", "Unknown"),
				"description": bonus.get("description", ""),
				"can_activate": can_activate_bonus(player_index, organ_type)
			})
	
	return bonus_info

## Get organ name from type
func _get_organ_name(organ_type: int) -> String:
	var names = ["BRAIN", "HEART", "LUNGS", "ARMS", "LEGS", "EYES", "PANCREAS", "LIVER", "KIDNEYS"]
	if organ_type >= 0 and organ_type < names.size():
		return names[organ_type]
	return "UNKNOWN"

## Check if player has any usable bonuses this turn
func has_usable_bonus(player_index: int) -> bool:
	var extra_organs = check_extra_organs(player_index)
	for organ_type in extra_organs:
		if can_activate_bonus(player_index, organ_type):
			return true
	return false

## Force reset all bonuses (e.g., at game end)
func reset_all() -> void:
	_bonus_activated_this_turn.clear()
	_survivor_active.clear()
	_breath_multiplier.clear()
	_mash_multiplier.clear()
	_movement_bonus.clear()
	_peek_active.clear()
	_money_multiplier.clear()
	_damage_reduction.clear()
	_income_bonus.clear()
