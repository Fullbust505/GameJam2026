extends Control
class_name Shop

## Shop Interface for Monsieur Monstre board game
## Allows players to purchase organs with their money

signal shop_opened(player_index: int)
signal organ_purchased(player_index: int, organ_type: int, price: int)
signal shop_closed(player_index: int)

var _game_state: Node = null
var _current_player_index: int = 0
var _price_multiplier: float = 1.0
var _animations: Node = null

# Base prices for organs (can be modified by rarity and player count)
const BASE_PRICES: Dictionary = {
	0: 50,   # BRAIN - expensive vital organ
	1: 40,   # HEART
	2: 30,   # LUNGS
	3: 25,   # ARMS
	4: 25,   # LEGS
	5: 35,   # EYES
	6: 20,   # PANCREAS
	7: 30,   # LIVER
	8: 35    # KIDNEYS
}

# Organ sprites mapping
const ORGAN_SPRITES: Dictionary = {
	0: "res://assets/sprites/heart.png",      # BRAIN
	1: "res://assets/sprites/heart.png",      # HEART
	2: "res://assets/sprites/eye.png",        # LUNGS
	3: "res://assets/sprites/arm.png",        # ARMS
	4: "res://assets/sprites/legs.png",       # LEGS
	5: "res://assets/sprites/eye.png",        # EYES
	6: "res://assets/sprites/pancreas.png",   # PANCREAS
	7: "res://assets/sprites/geiger_hand.png", # LIVER
	8: "res://assets/sprites/teeth.png"       # KIDNEYS
}

# Organ display names
const ORGAN_NAMES: Dictionary = {
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

func _ready() -> void:
	# Get animations helper
	_animations = get_node_or_null("/root/Animations")
	# Shop starts hidden
	hide_shop()

## Setup the shop with game state reference
func setup(game_state: Node) -> void:
	_game_state = game_state

## Connect to tile_event_executor's shop_requested signal
## Call this to automatically show shop when player lands on shop tile
func connect_to_tile_event_executor(tile_event_executor: Node) -> void:
	if tile_event_executor and tile_event_executor.has_signal("shop_requested"):
		tile_event_executor.connect("shop_requested", _on_tile_shop_requested)

func _on_tile_shop_requested(player_index: int, tile_data: Dictionary) -> void:
	setup_with_tile_data(player_index, tile_data)

## Get available shop items with calculated prices
func get_shop_items() -> Array:
	var items: Array = []
	
	# Get player count for price adjustment
	var player_count: int = 1
	if _game_state and _game_state.has("max_players"):
		player_count = _game_state.max_players
	
	# Calculate price multiplier based on player count
	# More players = slightly higher prices
	var player_multiplier: float = 1.0 + (player_count - 2) * 0.1 if player_count > 2 else 1.0
	
	for organ_type in range(9):  # 0-8 are the standard organs
		var base_price: int = BASE_PRICES.get(organ_type, 30)
		var final_price: int = int(base_price * _price_multiplier * player_multiplier)
		
		var item: Dictionary = {
			"organ_type": organ_type,
			"name": ORGAN_NAMES.get(organ_type, "Unknown"),
			"sprite_path": ORGAN_SPRITES.get(organ_type, ""),
			"base_price": base_price,
			"final_price": final_price
		}
		items.append(item)
	
	return items

## Show the shop interface for a player (with animation)
func show_shop(player_index: int) -> void:
	_current_player_index = player_index
	
	# Reset price multiplier
	_price_multiplier = 1.0
	
	# Make sure we have a valid player
	if not _game_state or player_index >= _game_state.players.size():
		hide_shop()
		return
	
	var player = _game_state.players[player_index]
	if not player:
		hide_shop()
		return
	
	# Update the shop UI
	_update_shop_display()
	
	# Show with animation
	if _animations:
		_animations.fade_in(self, 0.3)
	else:
		visible = true
	
	# Emit signal
	emit_signal("shop_opened", player_index)

## Update the shop display with current player info
func _update_shop_display() -> void:
	if not _game_state:
		return
	
	var player = _game_state.players[_current_player_index]
	if not player:
		return
	
	# Update player money display
	var money_label = get_node_or_null("VBox/MoneyContainer/MoneyLabel")
	if money_label:
		money_label.text = "$%d" % player.money
	
	# Update player name
	var player_label = get_node_or_null("VBox/PlayerLabel")
	if player_label:
		player_label.text = "Player %d's Shop" % (_current_player_index + 1)
	
	# Update organ grid
	var grid = get_node_or_null("VBox/OrganGrid")
	if grid:
		_update_organ_buttons(grid, player)

## Update organ buttons in the grid
func _update_organ_buttons(grid: Control, player) -> void:
	var items = get_shop_items()
	
	# Find the scroll container and grid inside it
	var scroll = grid
	var item_grid = scroll.get_node_or_null("GridContainer")
	if not item_grid:
		# Try to find HBox or other container
		item_grid = scroll
	
	var idx = 0
	for item in items:
		var organ_type = item["organ_type"]
		var price = item["final_price"]
		var can_afford = player.money >= price
		var already_owns = player.get_organ_count(organ_type) > 0
		
		# Find button for this organ (named "BuyButton_X")
		var button = item_grid.get_node_or_null("BuyButton_%d" % organ_type)
		if button:
			button.disabled = not can_afford
			
			# Update price label
			var price_label = button.get_node_or_null("VBox/PriceLabel")
			if price_label:
				price_label.text = "$%d" % price
			
			# Visual feedback for affordability
			var modulate = Color(1, 1, 1, 1) if can_afford else Color(0.5, 0.5, 0.5, 0.7)
			button.modulate = modulate
		
		idx += 1

## Handle purchase of an organ
func purchase_organ(player_index: int, organ_type: int) -> bool:
	if not _game_state or player_index >= _game_state.players.size():
		return false
	
	var player = _game_state.players[player_index]
	if not player:
		return false
	
	# Get price
	var items = get_shop_items()
	var price = 0
	for item in items:
		if item["organ_type"] == organ_type:
			price = item["final_price"]
			break
	
	# Check if player can afford
	if player.money < price:
		return false
	
	# Deduct money
	_game_state.modify_money(player_index, -price)
	
	# Add organ to player (using -1 as "from" to indicate shop)
	_game_state.transfer_organ(-1, player_index, organ_type)
	
	# Emit purchase signal
	emit_signal("organ_purchased", player_index, organ_type, price)
	
	# Refresh HUD if available
	_refresh_hud()
	
	# Update shop display (might have changed affordability)
	_update_shop_display()
	
	return true

## Hide the shop interface (with animation)
func hide_shop() -> void:
	if _animations:
		_animations.fade_out(self, 0.25, 0.0, true)
		await get_tree().create_timer(0.3).timeout
		visible = false
	else:
		visible = false
	emit_signal("shop_closed", _current_player_index)

## Refresh HUD after purchase
func _refresh_hud() -> void:
	# Find HUD and refresh it
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("refresh"):
		hud.refresh()

## Handle close button press
func _on_close_button_pressed() -> void:
	hide_shop()

## Handle buy button press for a specific organ
func _on_buy_button_pressed(organ_type: int) -> void:
	# Try to purchase
	if purchase_organ(_current_player_index, organ_type):
		# Show brief confirmation (could add visual feedback here)
		pass
	else:
		# Show that purchase failed (could add feedback here)
		pass

## Setup shop with tile data (price multiplier etc)
func setup_with_tile_data(player_index: int, tile_data: Dictionary) -> void:
	_price_multiplier = tile_data.get("price_multiplier", 1.0)
	show_shop(player_index)