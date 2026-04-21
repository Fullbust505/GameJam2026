extends Node
## Main Game Controller for Monsieur Monstre
## Manages the main game loop: roll dice → move player → execute tile effect → repeat

# Game phase states
enum GamePhase {
	SETUP,
	ROLL_DICE,
	MOVE_PLAYER,
	EXECUTE_TILE,
	SHOW_SHOP,
	SHOW_MINIGAME,
	END_TURN,
	GAME_OVER
}

# References to core systems
var game_state: Node = null
var board_generator: Node = null
var board_display: Node = null
var tile_event_executor: Node = null
var minigame_connection: Node = null
var hud: Node = null
var shop: Node = null

# UI References
var roll_button: Button = null
var status_label: Label = null

# Current game phase
var current_phase: int = GamePhase.SETUP

# Animation helper
var _animations: Node = null

# Script paths
const GAME_STATE_PATH := "res://scripts/core/game_state.gd"
const BOARD_GENERATOR_PATH := "res://scripts/core/board_generator.gd"
const TILE_EVENT_EXECUTOR_PATH := "res://scripts/core/tile_event_executor.gd"
const MINIGAME_CONNECTION_PATH := "res://scripts/core/minigame_connection.gd"

# Signals
signal game_started
signal turn_started(player_index: int)
signal phase_changed(phase: int)
signal game_ended(winner_id: int)

func _ready() -> void:
	# Get animations helper
	_animations = get_node_or_null("/root/Animations")
	
	# Initialize systems immediately in _ready
	_initialize_systems()
	_setup_ui()
	_connect_signals()
	
	# Auto-start the game after a short delay to let systems settle
	await get_tree().create_timer(0.5).timeout
	start_game(2, 25)

func _notification(what: int) -> void:
	# Notification handling removed - using _ready() instead
	pass

func _initialize_systems() -> void:
	# Game State
	game_state = get_node_or_null("GameState")
	if not game_state:
		var game_state_script = load(GAME_STATE_PATH)
		if game_state_script:
			game_state = game_state_script.new()
			game_state.name = "GameState"
			add_child(game_state)
			print("Game: Created GameState")
	
	# Board Generator
	board_generator = get_node_or_null("BoardGenerator")
	if not board_generator:
		var board_gen_script = load(BOARD_GENERATOR_PATH)
		if board_gen_script:
			board_generator = board_gen_script.new()
			board_generator.name = "BoardGenerator"
			add_child(board_generator)
			print("Game: Created BoardGenerator")
	
	# Tile Event Executor
	tile_event_executor = get_node_or_null("TileEventExecutor")
	if not tile_event_executor:
		var tile_exec_script = load(TILE_EVENT_EXECUTOR_PATH)
		if tile_exec_script:
			tile_event_executor = tile_exec_script.new()
			tile_event_executor.name = "TileEventExecutor"
			add_child(tile_event_executor)
			print("Game: Created TileEventExecutor")
	
	# Minigame Connection
	minigame_connection = get_node_or_null("MinigameConnection")
	if not minigame_connection:
		var minigame_conn_script = load(MINIGAME_CONNECTION_PATH)
		if minigame_conn_script:
			minigame_connection = minigame_conn_script.new()
			minigame_connection.name = "MinigameConnection"
			add_child(minigame_connection)
			print("Game: Created MinigameConnection")
	
	# Board Display - try to find in scene tree first, then fallback to manual instantiation
	# Note: BoardDisplay is now under BoardDisplayLayer (CanvasLayer), so use correct path
	print("Game._initialize_systems: Searching for BoardDisplay...")
	board_display = get_node_or_null("../BoardDisplayLayer/BoardDisplay")
	print("Game._initialize_systems: ../BoardDisplayLayer/BoardDisplay = ", board_display)
	if not board_display:
		board_display = get_node_or_null("/root/Game/BoardDisplayLayer/BoardDisplay")
		print("Game._initialize_systems: /root/Game/BoardDisplayLayer/BoardDisplay = ", board_display)
	if not board_display:
		board_display = get_node_or_null("/root/Game/BoardDisplay")  # Fallback for old path
		print("Game._initialize_systems: /root/Game/BoardDisplay = ", board_display)
	
	# Debug: Check parent type of board_display
	if board_display:
		var bd_parent = board_display.get_parent()
		print("DEBUG: BoardDisplay parent type: ", bd_parent.get_class() if bd_parent else "null")
		if bd_parent and not bd_parent is CanvasLayer and not bd_parent is Control:
			print("DEBUG WARNING: BoardDisplay is NOT under CanvasLayer or Control! This causes positioning issues.")
	
	# If not found, try to load the scene and instance manually
	if not board_display:
		var board_scene = load("res://scenes/board.tscn")
		if board_scene:
			board_display = board_scene.instantiate()
			if board_display:
				# Create a CanvasLayer to properly parent the Control node
				var canvas_layer = CanvasLayer.new()
				canvas_layer.name = "BoardDisplayLayer"
				canvas_layer.layer = 0
				var parent = get_parent()
				if parent:
					parent.add_child(canvas_layer)
				else:
					get_tree().root.add_child(canvas_layer)
				canvas_layer.add_child(board_display)
				print("Game: Instantiated BoardDisplay under new CanvasLayer")
	
	# HUD - try to find in scene tree first, then fallback to manual instantiation
	# Note: HUD is now under HUDLayer (CanvasLayer), so use correct path
	hud = get_node_or_null("../HUDLayer/HUD")
	if not hud:
		hud = get_node_or_null("/root/Game/HUDLayer/HUD")
	if not hud:
		hud = get_node_or_null("/root/Game/HUD")  # Fallback for old path
	
	# Debug: Check parent type of hud
	if hud:
		var hud_parent = hud.get_parent()
		print("DEBUG: HUD parent type: ", hud_parent.get_class() if hud_parent else "null")
		if hud_parent and not hud_parent is CanvasLayer and not hud_parent is Control:
			print("DEBUG WARNING: HUD is NOT under CanvasLayer or Control! This causes positioning issues.")
	
	# If not found, try to load the scene and instance manually
	if not hud:
		var hud_scene = load("res://scenes/hud.tscn")
		if hud_scene:
			hud = hud_scene.instantiate()
			if hud:
				# Create a CanvasLayer to properly parent the Control node
				var canvas_layer = CanvasLayer.new()
				canvas_layer.name = "HUDLayer"
				canvas_layer.layer = 1
				var parent = get_parent()
				if parent:
					parent.add_child(canvas_layer)
				else:
					get_tree().root.add_child(canvas_layer)
				canvas_layer.add_child(hud)
				print("Game: Instantiated HUD under new CanvasLayer")
	
	# Shop - try to find in scene tree first, then fallback to manual instantiation
	# Note: Shop is now under ShopLayer (CanvasLayer), so use correct path
	shop = get_node_or_null("../ShopLayer/Shop")
	if not shop:
		shop = get_node_or_null("/root/Game/ShopLayer/Shop")
	if not shop:
		shop = get_node_or_null("/root/Game/Shop")  # Fallback for old path
	
	# Debug: Check parent type of shop
	if shop:
		var shop_parent = shop.get_parent()
		print("DEBUG: Shop parent type: ", shop_parent.get_class() if shop_parent else "null")
		if shop_parent and not shop_parent is CanvasLayer and not shop_parent is Control:
			print("DEBUG WARNING: Shop is NOT under CanvasLayer or Control! This causes positioning issues.")
	
	# If not found, try to load the scene and instance manually
	if not shop:
		var shop_scene = load("res://scenes/shop.tscn")
		if shop_scene:
			shop = shop_scene.instantiate()
			if shop:
				# Create a CanvasLayer to properly parent the Control node
				var canvas_layer = CanvasLayer.new()
				canvas_layer.name = "ShopLayer"
				canvas_layer.layer = 2
				var parent = get_parent()
				if parent:
					parent.add_child(canvas_layer)
				else:
					get_tree().root.add_child(canvas_layer)
				canvas_layer.add_child(shop)
				shop.visible = false
				print("Game: Instantiated Shop under new CanvasLayer")
	
	# Setup references
	if tile_event_executor and game_state:
		tile_event_executor.setup(game_state)
	if minigame_connection and game_state:
		minigame_connection.setup(game_state)

func _setup_ui() -> void:
	# Get UI references from scene if they exist (UI is under CanvasLayer)
	# Note: Path changed to include UI layer
	roll_button = get_node_or_null("../UI/Control/VBox/CenterContainer/RollButton")
	status_label = get_node_or_null("../UI/Control/VBox/StatusLabel")
	
	# Connect button if exists
	if roll_button:
		roll_button.pressed.connect(_on_roll_button_pressed)
		roll_button.disabled = true
	
	# Add HUD to group for shop refresh
	if hud:
		hud.add_to_group("hud")

func _connect_signals() -> void:
	# Game state signals
	if game_state and game_state.has_signal("turn_changed"):
		game_state.turn_changed.connect(_on_turn_changed)
	if game_state and game_state.has_signal("tile_landed"):
		game_state.tile_landed.connect(_on_tile_landed)
	if game_state and game_state.has_signal("game_ended"):
		game_state.game_ended.connect(_on_game_ended)
	
	# Tile event executor signals
	if tile_event_executor:
		if tile_event_executor.has_signal("shop_requested"):
			tile_event_executor.shop_requested.connect(_on_shop_requested)
		if tile_event_executor.has_signal("challenge_requested"):
			tile_event_executor.challenge_requested.connect(_on_challenge_requested)
		if tile_event_executor.has_signal("tile_effect_completed"):
			tile_event_executor.tile_effect_completed.connect(_on_tile_effect_completed)
	
	# Minigame connection signals
	if minigame_connection:
		if minigame_connection.has_signal("minigame_ended"):
			minigame_connection.minigame_ended.connect(_on_minigame_ended)
		if tile_event_executor:
			minigame_connection.connect_to_tile_event_executor(tile_event_executor)
	
	# Shop signals
	if shop:
		if shop.has_signal("shop_closed"):
			shop.shop_closed.connect(_on_shop_closed)
		if shop.has_signal("organ_purchased"):
			shop.organ_purchased.connect(_on_organ_purchased)

## Start the game with specified settings
func start_game(num_players: int = 2, board_size: int = 25) -> void:
	print("Game: Starting game with ", num_players, " players, board size ", board_size)
	
	# Setup game state
	if game_state and game_state.has_method("setup_game"):
		game_state.setup_game(num_players, board_size)
	
	# Generate board
	var tiles = []
	if board_generator and board_generator.has_method("generate_board"):
		tiles = board_generator.generate_board(board_size)
	
	# Setup board display if available
	if board_display and board_display.has_method("setup"):
		print("Game: Calling board_display.setup() with ", tiles.size(), " tiles")
		var player_positions = []
		for i in range(num_players):
			player_positions.append(0)  # All players start at position 0
		# Board_display.setup() handles tree timing internally via is_inside_tree checks
		board_display.setup(tiles, player_positions)
	elif board_display:
		print("Game: board_display.setup() NOT called - board_display exists but no setup method")
	else:
		print("Game: board_display.setup() NOT called - board_display is null!")
	
	# Setup HUD if available
	if hud and hud.has_method("setup"):
		print("Game: Calling hud.setup()")
		hud.setup(game_state)
	else:
		print("Game: hud.setup() NOT called - hud: ", hud, " has_method(setup): ", hud.has_method("setup") if hud else false)
	
	# Setup shop connections
	if shop and tile_event_executor:
		shop.connect_to_tile_event_executor(tile_event_executor)
	
	# Start first turn
	_update_status("Player 1's turn - Roll the dice!")
	_set_phase(GamePhase.ROLL_DICE)
	
	# Enable roll button
	if roll_button:
		roll_button.disabled = false
	
	emit_signal("game_started")

## Main game phase update
func _set_phase(new_phase: int) -> void:
	current_phase = new_phase
	emit_signal("phase_changed", new_phase)

## Handle roll button pressed
func _on_roll_button_pressed() -> void:
	if current_phase != GamePhase.ROLL_DICE:
		return
	
	if not game_state:
		_end_turn()
		return
	
	# Roll dice
	var dice_result = game_state.roll_dice()
	print("Game: Player ", game_state.current_player_index + 1, " rolled ", dice_result)
	
	# Update status with dice result
	_update_status("Rolled " + str(dice_result) + "! Moving...")
	
	# Animate dice roll (if animations available)
	if _animations and roll_button and _animations.has_method("button_press"):
		_animations.button_press(roll_button)
	
	# Disable button during animation
	if roll_button:
		roll_button.disabled = true
	
	# Move to execute phase after brief delay
	_set_phase(GamePhase.MOVE_PLAYER)
	_execute_player_move(dice_result)

## Execute player movement
func _execute_player_move(spaces: int) -> void:
	if not game_state:
		_end_turn()
		return
	
	var player = game_state.get_current_player()
	if not player:
		_end_turn()
		return
	
	var old_position = player.position
	var board_size = 25
	if game_state.has_method("get_board_size"):
		board_size = game_state.get_board_size()
	var new_position = (player.position + spaces) % board_size
	
	# Update game state
	game_state.move_player(spaces)
	
	# Animate movement if board display available
	if board_display and board_display.has_method("update_player_position"):
		await get_tree().create_timer(0.3).timeout
		board_display.update_player_position(player.player_id, new_position)
	
	# Execute tile effect after movement animation
	await get_tree().create_timer(0.5).timeout
	_execute_tile_effect(new_position)

## Execute tile effect at position
func _execute_tile_effect(tile_position: int) -> void:
	if not tile_event_executor or not game_state:
		push_error("Game: Missing tile_event_executor or game_state!")
		_end_turn()
		return
	
	var tile = null
	if board_generator and board_generator.has_method("get_tile_at"):
		tile = board_generator.get_tile_at(tile_position)
	
	if not tile:
		push_error("Game: No tile found at position " + str(tile_position))
		_end_turn()
		return
	
	var tile_type_str = tile_event_executor.get_tile_type_string(tile.tile_type)
	print("Game: Player landed on ", tile_type_str, " tile at position ", tile_position)
	
	_update_status("Landed on " + tile_type_str + " tile!")
	
	# Check if we need to wait for UI (shop/minigame)
	# IMPORTANT: Set phase BEFORE emitting signals that might trigger _end_turn()
	if tile_type_str == "SHOP":
		_set_phase(GamePhase.SHOW_SHOP)
	elif tile_type_str == "CHALLENGE":
		_set_phase(GamePhase.SHOW_MINIGAME)
	else:
		_set_phase(GamePhase.EXECUTE_TILE)
	
	# Execute the tile effect (may emit signals for shop/minigame)
	print("Game: Calling execute_tile_effect for ", tile_type_str)
	var result = tile_event_executor.execute_tile_effect(
		game_state.current_player_index,
		tile_type_str,
		tile.properties
	)
	print("Game: execute_tile_effect returned for ", tile_type_str, ": ", result)
	
	# If SHOP or CHALLENGE, wait for the UI to close before ending turn
	if tile_type_str == "SHOP":
		print("Game: SHOP tile - waiting for shop to close")
		return  # Wait for shop to close
	elif tile_type_str == "CHALLENGE":
		print("Game: CHALLENGE tile - waiting for minigame")
		return  # Wait for minigame to complete
	
	# Otherwise, continue to end turn after delay
	print("Game: Non-interactive tile - will end turn after delay")
	await get_tree().create_timer(1.5).timeout
	_end_turn()

## Handle shop requested signal
func _on_shop_requested(player_index: int, tile_data: Dictionary) -> void:
	print("Game: _on_shop_requested called - player ", player_index, " tile_data ", tile_data)
	if shop:
		print("Game: shop reference exists, has setup_with_tile_data: ", shop.has_method("setup_with_tile_data"))
		if shop.has_method("setup_with_tile_data"):
			shop.setup_with_tile_data(player_index, tile_data)
			_update_status("Player " + str(player_index + 1) + " - Visit the shop!")
	else:
		push_error("Game: shop reference is null in _on_shop_requested!")

## Handle shop closed signal
func _on_shop_closed(player_index: int) -> void:
	print("Game: _on_shop_closed called - player ", player_index, " current_phase=", current_phase)
	# Only end turn if we're in SHOW_SHOP or SHOW_MINIGAME phase
	# Otherwise, the turn might have already been handled
	if current_phase != GamePhase.SHOW_SHOP and current_phase != GamePhase.SHOW_MINIGAME:
		print("Game: _on_shop_closed - not in interactive phase, ignoring")
		return
	
	_update_status("Shop closed. Ending turn...")
	# Shop is now closed, continue to end turn
	_end_turn()

## Handle organ purchased signal (for HUD refresh)
func _on_organ_purchased(player_index: int, organ_type: int, price: int) -> void:
	_update_status("Purchased organ for $" + str(price) + "!")
	# Refresh HUD after purchase
	if hud and hud.has_method("refresh"):
		hud.refresh()

## Handle challenge requested signal
func _on_challenge_requested(player_index: int, challenge_data: Dictionary) -> void:
	var organ_type = challenge_data.get("organ_type", -1)
	var organ_name = "Unknown"
	if game_state and game_state.has_method("get_organ_name"):
		organ_name = game_state.get_organ_name(organ_type) if organ_type >= 0 else "Unknown"
	_update_status("Challenge! Wagering " + organ_name)
	
	# Start minigame
	if minigame_connection:
		minigame_connection.start_minigame(player_index, organ_name, challenge_data.get("stake_multiplier", 1.0))

## Handle minigame ended
func _on_minigame_ended(player_index: int, success: bool, reward_data: Dictionary) -> void:
	print("Game: Minigame ended - Player ", player_index + 1, " ", "won" if success else "lost")
	
	var message = "Challenge " + ("WON!" if success else "LOST!")
	_update_status(message)
	
	# Apply reward/penalty via tile_event_executor
	if tile_event_executor and tile_event_executor.has_method("on_challenge_completed"):
		tile_event_executor.on_challenge_completed(player_index, success, reward_data)
	
	# Continue to end turn after brief delay
	await get_tree().create_timer(1.5).timeout
	_end_turn()

## Handle tile effect completed
func _on_tile_effect_completed(player_index: int, tile_type: String, result: Dictionary) -> void:
	if result.get("success", false):
		print("Game: Tile effect '", tile_type, "' result: ", result.get("message", ""))
	else:
		print("Game: Tile effect '", tile_type, "' failed: ", result.get("message", ""))

## End current turn and move to next player
func _end_turn() -> void:
	print("Game: _end_turn called - current_phase=", current_phase, " shop.visible=", shop.visible if shop else "null")
	
	# Check if shop is still open - if so, don't end turn yet
	if shop and shop.visible:
		print("Game: _end_turn skipped - shop is still visible")
		return  # Wait for shop to close
	
	# Don't end turn if we're in SHOW_SHOP or SHOW_MINIGAME phase
	if current_phase == GamePhase.SHOW_SHOP or current_phase == GamePhase.SHOW_MINIGAME:
		print("Game: _end_turn skipped - waiting for ", current_phase)
		return
	
	if not game_state:
		push_error("Game: _end_turn called but game_state is null")
		return
	
	# Check for game over
	if game_state.game_phase == 2:  # GamePhase.GAME_OVER = 2
		_set_phase(GamePhase.GAME_OVER)
		return
	
	# Move to next player
	game_state.next_player()
	
	# Check if game should end
	var max_turns = game_state.MAX_TURNS
	if game_state.current_turn >= max_turns:
		_end_game()
		return
	
	# Setup next turn
	_update_status("Player " + str(game_state.current_player_index + 1) + "'s turn - Roll the dice!")
	_set_phase(GamePhase.ROLL_DICE)
	
	# Enable roll button
	if roll_button:
		roll_button.disabled = false

## Handle turn changed signal
func _on_turn_changed(player_index: int) -> void:
	emit_signal("turn_started", player_index)

## Handle tile landed signal
func _on_tile_landed(player_id: int, tile_position: int) -> void:
	print("Game: Player ", player_id + 1, " landed on tile ", tile_position)

## Handle game ended signal
func _on_game_ended(winner_id: int) -> void:
	_end_game()

## End the game and show results
func _end_game() -> void:
	_set_phase(GamePhase.GAME_OVER)
	
	if not game_state:
		_update_status("Game Over! No winner.")
		emit_signal("game_ended", -1)
		_return_to_menu_after_delay()
		return
	
	var winner = null
	if game_state.has_method("get_winner"):
		winner = game_state.get_winner()
	
	var winner_id = -1
	var message = "Game Over!"
	if winner:
		winner_id = winner.player_id
		message = "Player " + str(winner_id + 1) + " wins with " + str(winner.score) + " points!"
	else:
		message = "No winner! All players eliminated."
	
	_update_status(message)
	
	# Disable roll button
	if roll_button:
		roll_button.disabled = true
	
	emit_signal("game_ended", winner_id)
	
	# Return to menu after delay
	_return_to_menu_after_delay()

func _return_to_menu_after_delay() -> void:
	await get_tree().create_timer(3.0).timeout
	_return_to_menu()

## Return to main menu
func _return_to_menu() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")

## Update status label
func _update_status(message: String) -> void:
	print("Game Status: ", message)
	if status_label:
		status_label.text = message

## Public method to close shop (called by shop UI)
func close_shop() -> void:
	if shop:
		shop.hide_shop()
	# Continue turn after shop closes
	await get_tree().create_timer(0.3).timeout
	_end_turn()

## Skip current player's turn (for AI or testing)
func skip_turn() -> void:
	_end_turn()
