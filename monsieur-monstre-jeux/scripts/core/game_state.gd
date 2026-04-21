extends Node

# Game state management for Monsieur Monstre board game

signal turn_changed(player_id: int)
signal score_updated(player_id: int, new_score: int)
signal money_updated(player_id: int, new_money: int)
signal organ_changed(player_id: int, organ_type: int, new_count: int)
signal game_ended(winner_id: int)
signal tile_landed(player_id: int, tile_position: int)

const MAX_TURNS := 20

enum TileType {
	SHOP,
	CHALLENGE,
	STEAL,
	SWAP,
	BONUS,
	PENALTY,
	EVENT,
	START
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

var game_phase: int = GamePhase.SETUP
var current_turn: int = 0
var current_player_index: int = 0
var max_players: int = 2
var players: Array = []
var board_size: int = 25

class PlayerState:
	var player_id: int
	var score: int = 0
	var money: int = 100  # Starting money
	var organs: Dictionary = {}
	var position: int = 0  # Board position
	var turns_without_brain: int = 0
	var is_eliminated: bool = false
	
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

func _ready() -> void:
	pass

func setup_game(num_players: int, board_sz: int = 25) -> void:
	max_players = num_players
	board_size = board_sz
	players.clear()
	for i in range(num_players):
		players.append(PlayerState.new(i))
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
	if current_turn >= MAX_TURNS:
		end_game()

func roll_dice() -> int:
	# Simple dice: 1-6
	return randi() % 6 + 1

func move_player(spaces: int) -> void:
	var player: PlayerState = get_current_player()
	if player and not player.is_eliminated:
		player.position = (player.position + spaces) % board_size
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
		# BUG FIX: Also emit organ_changed since money affects purchasing power
		emit_signal("organ_changed", player_id, -1, -1)

func can_be_stolen(organ_type: int) -> bool:
	# Brain cannot be stolen
	return organ_type != OrganType.BRAIN

func transfer_organ(from_player_id: int, to_player_id: int, organ_type: int) -> bool:
	if not can_be_stolen(organ_type):
		return false
	
	var from_player: PlayerState = null
	var to_player: PlayerState = null
	
	if from_player_id < players.size():
		from_player = players[from_player_id]
	if to_player_id < players.size():
		to_player = players[to_player_id]
	
	if from_player and to_player:
		if from_player.remove_organ(organ_type):
			to_player.add_organ(organ_type)
			emit_signal("organ_changed", from_player_id, organ_type, from_player.get_organ_count(organ_type))
			emit_signal("organ_changed", to_player_id, organ_type, to_player.get_organ_count(organ_type))
			
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
	# Returns array of player_ids at given position
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
		# Base is 2 for most paired organs, 1 for others
		var base: int = 2
		if organ_type == OrganType.HEART or organ_type == OrganType.LUNGS or organ_type == OrganType.PANCREAS or organ_type == OrganType.LIVER:
			base = 1
		if count >= base:
			return 0.5  # Easy - extra organs
		elif count == base - 1:
			return 1.0  # Medium - base amount
		elif count == 1:
			return 1.5  # Hard - one left
		else:
			return 2.0  # Very hard - none left
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
		for ot: int in OrganType.keys():
			var organ_type_val: int = OrganType.get(ot)
			if player.get_organ_count(organ_type_val) > 0 and can_be_stolen(organ_type_val):
				available.append(organ_type_val)
	return available

# Get organ name
func get_organ_name(organ_type: int) -> String:
	var keys: Array = OrganType.keys()
	if organ_type < keys.size():
		return keys[organ_type]
	return "Unknown"
