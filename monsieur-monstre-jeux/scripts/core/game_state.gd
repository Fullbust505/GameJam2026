extends Node

# Game state management for Monsieur Monstre board game

signal turn_changed(player_id: int)
signal score_updated(player_id: int, new_score: int)
signal money_updated(player_id: int, new_money: int)
signal organ_changed(player_id: int, organ_type: int, new_count: int)
signal game_ended(winner_id: int)
signal tile_landed(player_id: int, tile_position: int)

const MAX_TURNS := 20
const MAX_MAPS := 3

enum TileType {
	SHOP,
	CHALLENGE,
	STEAL,
	SWAP,
	BONUS,
	PENALTY,
	EVENT,
	START,
	END
}

enum GamePhase {
	SETUP,
	PLAYING,
	GAME_OVER
}

enum OrganType {
	BRAIN,
	HEART,
	LUNGS,
	ARMS,
	LEGS,
	EYES,
	PANCREAS,
	LIVER,
	KIDNEYS
}

# Organ importance categories for brain protection
const IMPORTANT_ORGANS: Array = [OrganType.HEART, OrganType.LUNGS, OrganType.BRAIN]
const NON_IMPORTANT_ORGANS: Array = [OrganType.ARMS, OrganType.LEGS, OrganType.EYES, OrganType.PANCREAS, OrganType.LIVER, OrganType.KIDNEYS]

var game_phase: int = GamePhase.SETUP
var current_turn: int = 0
var current_player_index: int = 0
var max_players: int = 2
var players: Array = []
var board_size: int = 25

# Map progression tracking
var current_map: int = 0
var maps_completed: int = 0

# Brain protection tracking per player
var _stolen_important_organs: Dictionary = {}
var _stolen_non_important_organs: Dictionary = {}

class PlayerState:
	var player_id: int
	var score: int = 0
	var money: int = 100  # Starting money
	var organs: Dictionary = {}
	var position: int = 0  # Board position
	var turns_without_brain: int = 0
	var is_eliminated: bool = false

	# Alcohol tracking for drinking minigame
	var alcohol_level: float = 0.0
	var is_in_coma: bool = false
	var coma_duration: float = 0.0

	func _init(p_id: int):
		player_id = p_id
		_init_organs()
	
	func _init_organs():
		organs[OrganType.BRAIN] = 1
		organs[OrganType.HEART] = 1
		organs[OrganType.LUNGS] = 1
		organs[OrganType.ARMS] = 2
		organs[OrganType.LEGS] = 2
		organs[OrganType.EYES] = 2
		organs[OrganType.PANCREAS] = 1
		organs[OrganType.LIVER] = 1
		organs[OrganType.KIDNEYS] = 2
	
	func get_organ_count(organ_type: int) -> int:
		return organs.get(organ_type, 0)
	
	func set_organ_count(organ_type: int, count: int) -> void:
		organs[organ_type] = max(0, count)
	
	func add_organ(organ_type: int) -> void:
		organs[organ_type] = organs.get(organ_type, 0) + 1
	
	func remove_organ(organ_type: int) -> bool:
		if organs.get(organ_type, 0) > 0:
			organs[organ_type] -= 1
			return true
		return false
	
	func has_brain() -> bool:
		return organs.get(OrganType.BRAIN, 0) > 0
	
	func eliminate() -> void:
		is_eliminated = true
	
	func can_win() -> bool:
		return not is_eliminated and has_brain()

	func get_total_organs() -> int:
		var total: int = 0
		for count_value in organs.values():
			total += count_value
		return total

	# Alcohol/coma state methods for drinking minigame
	func set_alcohol_level(level: float) -> void:
		alcohol_level = clamp(level, 0.0, 100.0)

	func get_alcohol_level() -> float:
		return alcohol_level

	func enter_coma(duration: float) -> void:
		is_in_coma = true
		coma_duration = max(0.0, duration)

	func exit_coma() -> void:
		is_in_coma = false
		coma_duration = 0.0

	func process_coma_decay(delta: float, metabolism_rate: float) -> void:
		if is_in_coma:
			coma_duration -= delta
			if coma_duration <= 0.0:
				exit_coma()
			else:
				alcohol_level = max(0.0, alcohol_level - (metabolism_rate * delta))

func _ready() -> void:
	pass

func setup_game(num_players: int, board_sz: int = 25) -> void:
	max_players = num_players
	board_size = board_sz
	players.clear()
	for i in range(num_players):
		players.append(PlayerState.new(i))
		_stolen_important_organs[i] = 0
		_stolen_non_important_organs[i] = 0
	game_phase = GamePhase.PLAYING
	current_turn = 0
	current_player_index = 0

func get_current_player() -> PlayerState:
	if current_player_index < players.size():
		return players[current_player_index]
	return null

func next_player() -> void:
	current_player_index += 1
	if current_player_index >= max_players:
		current_player_index = 0
		current_turn += 1
	emit_signal("turn_changed", current_player_index)

	# Check if game should end
	if check_game_end_conditions():
		end_game()

## Check if game should end based on turns and maps
func check_game_end_conditions() -> bool:
	if maps_completed >= MAX_MAPS:
		return true
	if current_turn >= MAX_TURNS:
		return true
	return false

## Called when a player reaches the END tile
func on_reached_end_tile() -> void:
	maps_completed += 1
	current_map += 1
	print("GameState: Player reached END! Maps completed: ", maps_completed, "/", MAX_MAPS)

## Get current map number (1-based for display)
func get_current_map() -> int:
	return current_map + 1

## Get total maps completed
func get_maps_completed() -> int:
	return maps_completed

func roll_dice() -> int:
	# Simple dice: 1-6
	return randi() % 6 + 1

func move_player(spaces: int) -> void:
	var player: PlayerState = get_current_player()
	if player and not player.is_eliminated:
		player.position = (player.position + spaces) % board_size
		emit_signal("tile_landed", player.player_id, player.position)

## Move player on linear board (no wrapping)
func move_player_linear(spaces: int) -> void:
	var player: PlayerState = get_current_player()
	if player and not player.is_eliminated:
		var new_pos = player.position + spaces
		if new_pos >= board_size:
			new_pos = board_size - 1
		player.position = new_pos
		emit_signal("tile_landed", player.player_id, player.position)

func modify_score(player_id: int, delta: int) -> void:
	if player_id < players.size():
		var p: PlayerState = players[player_id]
		p.score += delta
		emit_signal("score_updated", player_id, p.score)

func modify_money(player_id: int, delta: int) -> void:
	if player_id < players.size():
		var p: PlayerState = players[player_id]
		p.money += delta
		emit_signal("money_updated", player_id, p.money)
		emit_signal("organ_changed", player_id, -1, -1)

## Check if an organ type can be stolen (basic check - excludes brain)
func can_be_stolen(organ_type: int) -> bool:
	return organ_type != OrganType.BRAIN

## Check if brain can be stolen from a player
## Brain is protected until 2 non-important + 2 important organs have been stolen
func can_steal_brain(player_id: int) -> bool:
	if player_id < 0 or player_id >= max_players:
		return false
	var important_stolen: int = _stolen_important_organs.get(player_id, 0)
	var non_important_stolen: int = _stolen_non_important_organs.get(player_id, 0)
	return important_stolen >= 2 and non_important_stolen >= 2

## Check if a specific organ type can be stolen (includes brain protection)
func can_steal_organ(from_player_id: int, organ_type: int) -> bool:
	if organ_type == OrganType.BRAIN:
		return can_steal_brain(from_player_id)
	return can_be_stolen(organ_type)

## Internal: Record that an organ was stolen (for brain protection tracking)
func _record_organ_stolen(player_id: int, organ_type: int) -> void:
	if player_id < 0 or player_id >= max_players:
		return
	
	if IMPORTANT_ORGANS.has(organ_type):
		var current: int = _stolen_important_organs.get(player_id, 0)
		_stolen_important_organs[player_id] = current + 1
	elif NON_IMPORTANT_ORGANS.has(organ_type):
		var current: int = _stolen_non_important_organs.get(player_id, 0)
		_stolen_non_important_organs[player_id] = current + 1

## Transfer organ with brain protection tracking
func transfer_organ(from_player_id: int, to_player_id: int, organ_type: int) -> bool:
	if not can_steal_organ(from_player_id, organ_type):
		return false
	
	var from_player: PlayerState = null
	var to_player: PlayerState = null
	
	if from_player_id >= 0 and from_player_id < players.size():
		from_player = players[from_player_id]
	if to_player_id >= 0 and to_player_id < players.size():
		to_player = players[to_player_id]
	
	if from_player and to_player:
		if from_player.remove_organ(organ_type):
			to_player.add_organ(organ_type)
			emit_signal("organ_changed", from_player_id, organ_type, from_player.get_organ_count(organ_type))
			emit_signal("organ_changed", to_player_id, organ_type, to_player.get_organ_count(organ_type))
			
			# Track stolen organs for brain protection
			_record_organ_stolen(from_player_id, organ_type)
			
			# Check brain loss
			if organ_type == OrganType.BRAIN:
				from_player.turns_without_brain = 1
			return true
	return false

func check_brain_elimination(player_id: int) -> bool:
	var player: PlayerState = null
	if player_id < players.size():
		player = players[player_id]
	if player and not player.has_brain():
		player.turns_without_brain += 1
		if player.turns_without_brain >= 2:
			player.eliminate()
			return true
	return false

func get_winner() -> PlayerState:
	var best_score: int = -1
	var winner: PlayerState = null
	for p: PlayerState in players:
		if p.can_win() and p.score > best_score:
			best_score = p.score
			winner = p
	return winner

func end_game() -> void:
	game_phase = GamePhase.GAME_OVER
	var winner: PlayerState = get_winner()
	if winner:
		emit_signal("game_ended", winner.player_id)

func get_board_size() -> int:
	return board_size

func get_player_at_position(board_position: int) -> Array:
	var result: Array = []
	for p: PlayerState in players:
		if p.position == board_position and not p.is_eliminated:
			result.append(p.player_id)
	return result

func get_active_players() -> Array:
	var active: Array = []
	for p: PlayerState in players:
		if not p.is_eliminated:
			active.append(p.player_id)
	return active

# Get challenge difficulty for a player and organ type
func get_challenge_difficulty(player_id: int, organ_type: int) -> float:
	var player: PlayerState = null
	if player_id < players.size():
		player = players[player_id]
	if player:
		var count: int = player.get_organ_count(organ_type)
		var base: int = 2
		if organ_type == OrganType.HEART or organ_type == OrganType.LUNGS or organ_type == OrganType.PANCREAS or organ_type == OrganType.LIVER:
			base = 1
		if count >= base:
			return 0.5
		elif count == base - 1:
			return 1.0
		elif count == 1:
			return 1.5
		else:
			return 2.0
	return 1.0

# Check if player has organ available for challenge
func can_challenge(player_id: int, organ_type: int) -> bool:
	var player: PlayerState = null
	if player_id < players.size():
		player = players[player_id]
	if player:
		return player.get_organ_count(organ_type) > 0 and can_be_stolen(organ_type)
	return false

# Get organ types available for challenge from a player
func get_available_organs_for_stealing(player_id: int) -> Array:
	var player: PlayerState = null
	if player_id < players.size():
		player = players[player_id]
	var available: Array = []
	if player:
		for ot: String in OrganType.keys():
			var organ_type_val: int = OrganType.get(ot)
			if player.get_organ_count(organ_type_val) > 0 and can_steal_organ(player_id, organ_type_val):
				available.append(organ_type_val)
	return available

# Get organ name
func get_organ_name(organ_type: int) -> String:
	var keys: Array = OrganType.keys()
	if organ_type < keys.size():
		return keys[organ_type]
	return "Unknown"

## Get brain protection status for a player
func get_brain_protection_status(player_id: int) -> Dictionary:
	if player_id < 0 or player_id >= max_players:
		return {"protected": true, "important_stolen": 0, "non_important_stolen": 0}
	
	var important_stolen: int = _stolen_important_organs.get(player_id, 0)
	var non_important_stolen: int = _stolen_non_important_organs.get(player_id, 0)
	var brain_protected: bool = not can_steal_brain(player_id)
	
	return {
		"protected": brain_protected,
		"important_stolen": important_stolen,
		"non_important_stolen": non_important_stolen,
		"important_required": 2,
		"non_important_required": 2
	}

## Reset brain protection tracking (for new game)
func reset_brain_protection() -> void:
	_stolen_important_organs.clear()
	_stolen_non_important_organs.clear()
	for i in range(max_players):
		_stolen_important_organs[i] = 0
		_stolen_non_important_organs[i] = 0
