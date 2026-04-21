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
	START
}

class Tile:
	var tile_type: int
	var position: int
	var properties: Dictionary
	
	func _init(type: int, pos: int, props: Dictionary = {}):
		tile_type = type
		position = pos
		properties = props
	
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
		return "UNKNOWN"

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
		weights[TILE_WEIGHTS.keys()[0]] += 10  # Challenge
		weights[TILE_WEIGHTS.keys()[1]] += 10  # Bonus
	elif normalized_pos < 0.75:
		# Mid game - favor challenge and steal
		weights[TILE_WEIGHTS.keys()[0]] += 10  # Challenge
	else:
		# Late game - favor event and swap
		weights[TILE_WEIGHTS.keys()[6]] += 10  # Event
	
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
	# Organ types enum from OrganData
	var organs: Array = [0, 1, 2, 3, 4, 5, 6, 7]  # BRAIN=0, HEART=1, LUNGS=2, etc.
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
