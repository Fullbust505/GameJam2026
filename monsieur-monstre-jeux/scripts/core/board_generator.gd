extends Node

# Procedural board generator for Monsieur Monstre

signal board_generated(tiles: Array)

const MIN_BOARD_SIZE := 12
const MAX_BOARD_SIZE := 36

enum TileType {
	SHOP,
	CHALLENGE,
	STEAL,
	SWAP,
	BONUS,
	PENALTY,
	EVENT,
	START,
	END,
	PATH_SPLIT,    # Branch point - player chooses which path
	PATH_MERGE     # Merge point - paths rejoin here
}

class Tile:
	var tile_type: int
	var position: int
	var properties: Dictionary
	var connections: Array = []  # Which tiles this tile connects to (for branches)

	func _init(type: int, pos: int, props: Dictionary = {}):
		tile_type = type
		position = pos
		properties = props
		connections = []

	func get_display_name() -> String:
		match tile_type:
			TileType.SHOP:
				return "SHOP"
			TileType.CHALLENGE:
				return "CHALLENGE"
			TileType.STEAL:
				return "STEAL"
			TileType.SWAP:
				return "SWAP"
			TileType.BONUS:
				return "BONUS"
			TileType.PENALTY:
				return "PENALTY"
			TileType.EVENT:
				return "EVENT"
			TileType.START:
				return "START"
			TileType.END:
				return "END"
			TileType.PATH_SPLIT:
				return "SPLIT"
			TileType.PATH_MERGE:
				return "MERGE"
		return "UNKNOWN"

	func add_connection(tile_idx: int) -> void:
		if not connections.has(tile_idx):
			connections.append(tile_idx)

# Tile distribution weights (higher = more common)
const TILE_WEIGHTS := {
	TileType.CHALLENGE: 25,
	TileType.BONUS: 15,
	TileType.PENALTY: 15,
	TileType.SHOP: 15,
	TileType.STEAL: 10,
	TileType.SWAP: 10,
	TileType.EVENT: 10
}

var current_board: Array = []
var current_map: int = 0

func _ready() -> void:
	pass

# Generate a random board
func generate_board(size: int = 0) -> Array:
	if size < MIN_BOARD_SIZE or size > MAX_BOARD_SIZE:
		size = randi() % (MAX_BOARD_SIZE - MIN_BOARD_SIZE + 1) + MIN_BOARD_SIZE
	
	current_board.clear()
	
	# Always start with START tile
	current_board.append(Tile.new(TileType.START, 0))
	
	# Generate remaining tiles
	for i in range(1, size):
		var tile_type_int: int = _select_random_tile_type(i, size)
		var properties: Dictionary = _generate_tile_properties(tile_type_int)
		current_board.append(Tile.new(tile_type_int, i, properties))
	
	# Ensure fair distribution by adjusting
	_adjust_distribution()
	
	emit_signal("board_generated", current_board)
	return current_board

# Generate a linear board with branches (START -> middle tiles -> END)
func generate_linear_board(size: int = 0) -> Array:
	current_map += 1
	if size < MIN_BOARD_SIZE or size > MAX_BOARD_SIZE:
		size = randi() % (MAX_BOARD_SIZE - MIN_BOARD_SIZE + 1) + MIN_BOARD_SIZE

	current_board.clear()

	# Strategy: Build a board with potential branch points
	# SPLIT tiles create parallel paths that MERGE back later

	# Always start with START tile at position 0
	current_board.append(Tile.new(TileType.START, 0, {}))

	# Create the board with strategic split/merge points
	var mid_size = size - 2  # Without START and END
	var split_positions: Array = []
	var merge_positions: Array = []

	# Add 2-3 split points randomly
	var num_splits = randi() % 2 + 2  # 2-3 splits
	for i in range(num_splits):
		var pos = int((i + 1) * mid_size / float(num_splits + 1))
		split_positions.append(pos)

	# Create main path tiles
	for i in range(1, size - 1):
		var tile_type_int: int
		var props: Dictionary = {}

		# Check if this should be a SPLIT tile
		if split_positions.has(i):
			tile_type_int = TileType.PATH_SPLIT
		# Check if this should be a MERGE tile (roughly after splits)
		elif i > split_positions[0] + 3 and randi() % 4 == 0 and merge_positions.size() < split_positions.size():
			tile_type_int = TileType.PATH_MERGE
			merge_positions.append(i)
		else:
			tile_type_int = _select_random_tile_type(i, size)
			props = _generate_tile_properties(tile_type_int)

		current_board.append(Tile.new(tile_type_int, i, props))

	# Always end with END tile at final position
	current_board.append(Tile.new(TileType.END, size - 1, {}))

	# Build branch connections (simplified: SPLIT connects to next 2 tiles)
	_build_branch_connections(split_positions, merge_positions)

	# Ensure fair distribution
	_adjust_distribution_linear()

	emit_signal("board_generated", current_board)
	return current_board

# Build connection information for branched paths
func _build_branch_connections(split_positions: Array, merge_positions: Array) -> void:
	# For each SPLIT, connect it to the next logical tiles
	# The actual branch choice is made during gameplay
	for split_pos in split_positions:
		if split_pos < current_board.size():
			var split_tile = current_board[split_pos]
			# Connect to next tile (main path) and skip-one tile (branch path)
			split_tile.add_connection(split_pos + 1)
			if split_pos + 2 < current_board.size():
				split_tile.add_connection(split_pos + 2)

	# For each MERGE, it's the end of a branch - connect back to main path
	for merge_pos in merge_positions:
		if merge_pos < current_board.size():
			var merge_tile = current_board[merge_pos]
			# Merge connects forward to continue main path
			if merge_pos + 1 < current_board.size():
				merge_tile.add_connection(merge_pos + 1)

# Ensure fair tile distribution for linear board
func _adjust_distribution_linear() -> void:
	var counts: Dictionary = {}
	for tile in current_board:
		var t: int = tile.tile_type
		if t != TileType.START and t != TileType.END and t != TileType.PATH_SPLIT and t != TileType.PATH_MERGE:
			counts[t] = counts.get(t, 0) + 1

	# Check for missing tile types
	var required_types: Array = [
		TileType.SHOP,
		TileType.CHALLENGE,
		TileType.BONUS,
		TileType.PENALTY
	]

	for req_type in required_types:
		if not counts.has(req_type) or counts[req_type] < 2:
			_add_tile_of_type_linear(req_type)

# Helper to add tile of specific type in linear board
func _add_tile_of_type_linear(tile_type: int) -> void:
	if current_board.is_empty():
		return

	# Find a random position between START (0) and END (last)
	var max_pos = current_board.size() - 1
	if max_pos <= 1:
		return
	var pos: int = randi() % (max_pos - 1) + 1  # Don't replace START or END
	var props: Dictionary = _generate_tile_properties(tile_type)
	current_board[pos] = Tile.new(tile_type, pos, props)

# Select random tile type based on weights
func _select_random_tile_type(position: int, total_size: int) -> int:
	var weights: Dictionary = TILE_WEIGHTS.duplicate()
	
	# Adjust weights based on position
	# Early game: more shop and bonus
	# Mid game: more challenge and steal
	# Late game: more event and penalty
	
	var normalized_pos: float = float(position) / float(total_size)
	
	if normalized_pos < 0.25:
		# Early game - favor shop and bonus
		weights[TileType.CHALLENGE] += 10
		weights[TileType.BONUS] += 10
	elif normalized_pos < 0.75:
		# Mid game - favor challenge and steal
		weights[TileType.CHALLENGE] += 10
	else:
		# Late game - favor event and swap
		weights[TileType.EVENT] += 10
	
	# Build weighted pool
	var pool: Array = []
	for tile_type in weights.keys():
		for _i in range(weights[tile_type]):
			pool.append(tile_type)
	
	if pool.is_empty():
		return TileType.CHALLENGE
	
	return pool[randi() % pool.size()]

# Generate properties for a tile
func _generate_tile_properties(tile_type: int) -> Dictionary:
	var props: Dictionary = {}
	
	match tile_type:
		TileType.SHOP:
			props["price_multiplier"] = randf_range(0.8, 1.2)
		
		TileType.CHALLENGE:
			props["organ_type"] = _random_organ_type()
			props["stake_multiplier"] = randf_range(0.5, 2.0)
		
		TileType.STEAL:
			props["success_chance"] = randf_range(0.3, 0.8)
			props["penalty_on_fail"] = randi() % 2 == 1
		
		TileType.SWAP:
			props["forced"] = randi() % 3 == 0  # 1/3 chance forced swap
		
		TileType.BONUS:
			props["money"] = (randi() % 50 + 10) * 10  # 10-60 in steps of 10
			props["score"] = randi() % 20 + 5
		
		TileType.PENALTY:
			props["money_loss"] = (randi() % 30 + 10) * 10  # 10-40 in steps of 10
			props["score_loss"] = randi() % 10 + 5
		
		TileType.EVENT:
			props["event_type"] = _random_event_type()
	
	return props

# Get random organ type (for challenge tiles)
func _random_organ_type() -> int:
	# Organ types 1-8 (skip 0=BRAIN which can't be stolen or wagered)
	var organs: Array = [1, 2, 3, 4, 5, 6, 7, 8]  # HEART, LUNGS, ARMS, LEGS, EYES, PANCREAS, LIVER, KIDNEYS
	return organs[randi() % organs.size()]

# Get random event type
func _random_event_type() -> String:
	var events: Array = [
		"random_teleport",
		"money_steal",
		"free_shopping",
		"double_challenge",
		"reverse_order"
	]
	return events[randi() % events.size()]

# Ensure fair tile distribution
func _adjust_distribution() -> void:
	var counts: Dictionary = {}
	for tile in current_board:
		var t: int = tile.tile_type
		counts[t] = counts.get(t, 0) + 1
	
	# Check for missing tile types
	var required_types: Array = [
		TileType.SHOP,
		TileType.CHALLENGE,
		TileType.BONUS,
		TileType.PENALTY
	]
	
	for req_type in required_types:
		if not counts.has(req_type) or counts[req_type] < 2:
			# Add at least 2 of each required type
			_add_tile_of_type(req_type)

# Helper to add tile of specific type
func _add_tile_of_type(tile_type: int) -> void:
	if current_board.is_empty():
		return
	
	# Find a random position to replace
	var pos: int = randi() % (current_board.size() - 1) + 1  # Don't replace start
	var props: Dictionary = _generate_tile_properties(tile_type)
	current_board[pos] = Tile.new(tile_type, pos, props)

# Get current board
func get_board() -> Array:
	return current_board

# Get tile at position
func get_tile_at(position: int) -> Tile:
	if position < current_board.size():
		return current_board[position]
	return null

# Get board size
func get_board_size() -> int:
	return current_board.size()
