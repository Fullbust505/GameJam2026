extends Node

# Handles player turn-based movement and tile interactions

signal dice_rolled(player_id: int, result: int)
signal player_moved(player_id: int, new_position: int)
signal tile_action_started(player_id: int, tile_type: int)
signal tile_action_completed(player_id: int, result: String)

var game_state: Node  # Reference to GameState
var board_generator: Node  # Reference to BoardGenerator

var is_processing_turn: bool = false

func _ready() -> void:
	pass

func setup(gs: Node, bg: Node) -> void:
	game_state = gs
	board_generator = bg

# Execute a full turn for current player
func execute_turn() -> void:
	if is_processing_turn:
		return
	
	var player = game_state.get_current_player()
	if not player or player.is_eliminated:
		game_state.next_player()
		return
	
	is_processing_turn = true
	
	# Roll dice
	var dice_result: int = game_state.roll_dice()
	emit_signal("dice_rolled", player.player_id, dice_result)
	
	# Wait a moment for UI to show dice
	await get_tree().create_timer(0.5).timeout
	
	# Move player
	game_state.move_player(dice_result)
	emit_signal("player_moved", player.player_id, player.position)
	
	# Get tile at new position
	var tile = board_generator.get_tile_at(player.position)
	if tile:
		emit_signal("tile_action_started", player.player_id, tile.tile_type)
		await _execute_tile_action(player, tile)
		emit_signal("tile_action_completed", player.player_id, "completed")
	
	is_processing_turn = false
	
	# Move to next player
	game_state.next_player()

# Execute the action for a specific tile
func _execute_tile_action(player, tile) -> void:
	match tile.tile_type:
		0:  # SHOP
			await _handle_shop_tile(player, tile)
		1:  # CHALLENGE
			await _handle_challenge_tile(player, tile)
		2:  # STEAL
			await _handle_steal_tile(player, tile)
		3:  # SWAP
			await _handle_swap_tile(player, tile)
		4:  # BONUS
			_handle_bonus_tile(player, tile)
		5:  # PENALTY
			_handle_penalty_tile(player, tile)
		6:  # EVENT
			await _handle_event_tile(player, tile)

# Handle shop tile
func _handle_shop_tile(player, tile) -> void:
	# Shop logic - player can buy/sell organs
	# This would trigger a UI for shop interaction
	print("Player %d landed on SHOP" % player.player_id)
	# Shop state would be handled by UI layer

# Handle challenge tile
func _handle_challenge_tile(player, tile) -> void:
	# Get organ type for this challenge
	var organ_type: int = tile.properties.get("organ_type", 3)  # Default to ARMS
	
	# Find opponents with this organ
	var opponents: Array = []
	for i: int in range(game_state.players.size()):
		if i != player.player_id and game_state.can_challenge(i, organ_type):
			opponents.append(i)
	
	if opponents.is_empty():
		# No valid target, skip
		print("No valid opponents for challenge")
		return
	
	# Select random opponent
	var target_id: int = opponents[randi() % opponents.size()]
	
	# Fire minigame for this organ type
	# This would trigger the minigame system
	var organ_name: String = game_state.get_organ_name(organ_type)
	print("Player %d challenges Player %d for %s" % [player.player_id, target_id, organ_name])

# Handle steal tile
func _handle_steal_tile(player, tile) -> void:
	# Find opponent to steal from
	var opponents: Array = []
	for i: int in range(game_state.players.size()):
		if i != player.player_id:
			var available: Array = game_state.get_available_organs_for_stealing(i)
			if not available.is_empty():
				opponents.append(i)
	
	if opponents.is_empty():
		return
	
	# Select random opponent
	var target_id: int = opponents[randi() % opponents.size()]
	var available: Array = game_state.get_available_organs_for_stealing(target_id)
	var organ_to_steal: int = available[randi() % available.size()]
	
	# Success chance
	var success_chance: float = tile.properties.get("success_chance", 0.7)
	var roll: float = randf()
	
	if roll < success_chance:
		# Success!
		game_state.transfer_organ(target_id, player.player_id, organ_to_steal)
		var organ_name: String = game_state.get_organ_name(organ_to_steal)
		print("Player %d stole %s from Player %d" % [player.player_id, organ_name, target_id])
	else:
		# Failed
		var penalty: bool = tile.properties.get("penalty_on_fail", false)
		if penalty:
			game_state.modify_money(player.player_id, -25)
			print("Steal failed! Player %d lost 25 money" % player.player_id)

# Handle swap tile
func _handle_swap_tile(player, tile) -> void:
	var forced: bool = tile.properties.get("forced", false)
	
	# Find opponent to swap with
	var opponents: Array = []
	for i: int in range(game_state.players.size()):
		if i != player.player_id:
			opponents.append(i)
	
	if opponents.is_empty():
		return
	
	var target_id: int = opponents[randi() % opponents.size()]
	
	# Get available organs from both players
	var player_organs: Array = game_state.get_available_organs_for_stealing(player.player_id)
	var target_organs: Array = game_state.get_available_organs_for_stealing(target_id)
	
	if player_organs.is_empty() or target_organs.is_empty():
		return
	
	# Random organs to swap
	var player_organ: int = player_organs[randi() % player_organs.size()]
	var target_organ: int = target_organs[randi() % target_organs.size()]
	
	# Perform swap
	game_state.transfer_organ(player.player_id, target_id, player_organ)
	game_state.transfer_organ(target_id, player.player_id, target_organ)
	var player_organ_name: String = game_state.get_organ_name(player_organ)
	var target_organ_name: String = game_state.get_organ_name(target_organ)
	print("Player %d and Player %d swapped %s and %s" % [player.player_id, target_id, player_organ_name, target_organ_name])

# Handle bonus tile
func _handle_bonus_tile(player, tile) -> void:
	var money: int = tile.properties.get("money", 20)
	var score: int = tile.properties.get("score", 5)
	
	game_state.modify_money(player.player_id, money)
	game_state.modify_score(player.player_id, score)
	print("Player %d got +%d money and +%d score" % [player.player_id, money, score])

# Handle penalty tile
func _handle_penalty_tile(player, tile) -> void:
	var money_loss: int = tile.properties.get("money_loss", 20)
	var score_loss: int = tile.properties.get("score_loss", 5)
	
	game_state.modify_money(player.player_id, -money_loss)
	game_state.modify_score(player.player_id, -score_loss)
	print("Player %d lost %d money and %d score" % [player.player_id, money_loss, score_loss])

# Handle event tile
func _handle_event_tile(player, tile) -> void:
	var event_type: String = tile.properties.get("event_type", "random_teleport")
	
	match event_type:
		"random_teleport":
			var new_pos: int = randi() % board_generator.get_board_size()
			player.position = new_pos
			print("Player %d teleported to position %d" % [player.player_id, new_pos])
		
		"money_steal":
			# Steal from random opponent
			var opponents: Array = []
			for i: int in range(game_state.players.size()):
				if i != player.player_id:
					opponents.append(i)
			if not opponents.is_empty():
				var target: int = opponents[randi() % opponents.size()]
				game_state.modify_money(target, -30)
				game_state.modify_money(player.player_id, 30)
				print("Player %d stole 30 money from Player %d" % [player.player_id, target])
		
		"free_shopping":
			# Give bonus money
			game_state.modify_money(player.player_id, 50)
			print("Player %d got 50 free money!" % player.player_id)
		
		"double_challenge":
			# Next challenge is doubled stakes
			print("Player %d has double challenge next!" % player.player_id)
		
		"reverse_order":
			# Reverse player order - complex to implement
			print("Player order reversed!")

# Handle minigame result
func on_minigame_completed(winner_id: int, loser_id: int, organ_type: int) -> void:
	if winner_id != loser_id:
		game_state.transfer_organ(loser_id, winner_id, organ_type)
		game_state.modify_score(winner_id, 10)
		game_state.modify_score(loser_id, -5)
		var organ_name: String = game_state.get_organ_name(organ_type)
		print("Player %d won %s from Player %d!" % [winner_id, organ_name, loser_id])
