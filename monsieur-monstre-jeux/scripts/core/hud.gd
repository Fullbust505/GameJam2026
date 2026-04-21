extends Control

## Score/Organs HUD for Monsieur Monstre board game
## Displays player stats including money, score, and owned organs - SIMPLIFIED vertical list layout

signal setup_complete

var _game_state = null
var _player_rows: Array = []
var _current_player_index: int = 0
var _animations: Node = null

# Player colors for P1-P4
const PLAYER_COLORS: Array = [
	Color(0.2, 0.4, 0.8, 1.0),   # Blue for P1
	Color(0.8, 0.2, 0.2, 1.0),   # Red for P2
	Color(0.2, 0.7, 0.2, 1.0),   # Green for P3
	Color(0.8, 0.7, 0.1, 1.0)    # Yellow for P4
]

# Organ sprite paths mapping based on organ type index
const ORGAN_SPRITES: Dictionary = {
	0: "res://assets/sprites/brain.png",      # BRAIN
	1: "res://assets/sprites/heart.png",      # HEART
	2: "res://assets/sprites/eye.png",        # LUNGS
	3: "res://assets/sprites/arm.png",        # ARMS
	4: "res://assets/sprites/legs.png",       # LEGS
	5: "res://assets/sprites/eye.png",        # EYES
	6: "res://assets/sprites/pancreas.png",   # PANCREAS
	7: "res://assets/sprites/geiger_hand.png", # LIVER
	8: "res://assets/sprites/teeth.png"       # KIDNEYS
}

# Organ display order (most important first)
const ORGAN_DISPLAY_ORDER: Array = [1, 5, 3, 4, 2, 6, 7, 8, 0]  # HEART, EYES, ARMS, LEGS, LUNGS, PANCREAS, LIVER, KIDNEYS, BRAIN

# Small icon size for horizontal row
const ORGAN_ICON_SIZE: Vector2 = Vector2(24, 24)

func _ready() -> void:
	# Get animations helper
	_animations = get_node_or_null("/root/Animations")

## Setup the HUD with a game state reference
func setup(game_state) -> void:
	_game_state = game_state
	
	# Connect to game state signals
	if _game_state and _game_state.has_signal("turn_changed"):
		_game_state.turn_changed.connect(_on_turn_changed)
		_game_state.score_updated.connect(_on_score_updated)
		_game_state.money_updated.connect(_on_money_updated)
		_game_state.organ_changed.connect(_on_organ_changed)
		_game_state.game_ended.connect(_on_game_ended)
	
	# Store references to player rows
	_player_rows = []
	for i in range(4):  # Support up to 4 players
		var row = get_node_or_null("PlayerContainer/PlayerRow%d" % i)
		if row:
			_player_rows.append(row)
	
	refresh()
	setup_complete.emit()

## Refresh all display values
func refresh() -> void:
	if not _game_state:
		return
	
	# Use actual number of player rows that exist in the scene
	# This ensures we only show players that have UI rows available
	var num_players = min(_player_rows.size(), _game_state.max_players)
	
	# Update each player's display
	for i in range(num_players):
		_update_player_display(i)

## Update display for a specific player
func _update_player_display(player_index: int) -> void:
	if not _game_state or player_index >= _game_state.players.size():
		return
	
	var player = _game_state.players[player_index]
	if not player:
		return
	
	var row = _player_rows[player_index]
	if not row:
		return
	
	# Update name label
	var name_label = row.get_node_or_null("NameLabel")
	if name_label:
		name_label.text = "P%d" % (player_index + 1)
	
	# Update money label
	var money_label = row.get_node_or_null("MoneyLabel")
	if money_label:
		money_label.text = "$%d" % player.money
	
	# Update score label
	var score_label = row.get_node_or_null("ScoreLabel")
	if score_label:
		score_label.text = "%d" % player.score
	
	# Update organ icons in the horizontal row
	_update_organ_row_display(player_index, player)
	
	# Update color indicator
	var color_indicator = row.get_node_or_null("ColorIndicator")
	if color_indicator:
		if player_index == _current_player_index:
			color_indicator.color = PLAYER_COLORS[player_index]
		else:
			color_indicator.color = PLAYER_COLORS[player_index].darkened(0.5)

## Update organ display for a player - creates small icons in horizontal row
func _update_organ_row_display(player_index: int, player) -> void:
	var row = _player_rows[player_index]
	if not row:
		return
	
	var organs_row = row.get_node_or_null("OrgansRow")
	if not organs_row:
		return
	
	# Clear existing organ icons
	for child in organs_row.get_children():
		child.queue_free()
	
	# Add icons for each organ the player has
	for organ_type in ORGAN_DISPLAY_ORDER:
		var count = player.get_organ_count(organ_type)
		if count > 0:
			var icon = _create_organ_icon(organ_type, count)
			organs_row.add_child(icon)

## Create a small organ icon texture rect
func _create_organ_icon(organ_type: int, count: int) -> TextureRect:
	var icon = TextureRect.new()
	icon.custom_minimum_size = ORGAN_ICON_SIZE
	icon.expand = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var sprite_path = ORGAN_SPRITES.get(organ_type, "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		icon.texture = load(sprite_path)
	
	return icon

# Signal handlers
func _on_turn_changed(player_index: int) -> void:
	_current_player_index = player_index
	_highlight_current_player(player_index)

func _on_score_updated(player_id: int, new_score: int) -> void:
	if player_id < _player_rows.size():
		var row = _player_rows[player_id]
		var score_label = row.get_node_or_null("ScoreLabel")
		if score_label:
			# Get old value for animation
			var old_text = score_label.text
			var old_value = 0
			if old_text.is_valid_int():
				old_value = int(old_text)
			
			# Animate the number change
			if _animations:
				_animations.score_tick(score_label, old_value, new_score)
			else:
				score_label.text = "%d" % new_score

func _on_money_updated(player_id: int, new_money: int) -> void:
	if player_id < _player_rows.size():
		var row = _player_rows[player_id]
		var money_label = row.get_node_or_null("MoneyLabel")
		if money_label:
			# Get old value for animation
			var old_text = money_label.text
			var old_value = 0
			if "$" in old_text:
				old_value = int(old_text.replace("$", ""))
			
			# Animate the number change with flash effect
			if _animations:
				_animations.money_tick(money_label, old_value, new_money)
			else:
				money_label.text = "$%d" % new_money

func _on_organ_changed(player_id: int, organ_type: int, new_count: int) -> void:
	if player_id < _player_rows.size() and _game_state and player_id < _game_state.players.size():
		var player = _game_state.players[player_id]
		_update_organ_row_display(player_id, player)

func _on_game_ended(winner_id: int) -> void:
	# Could show a game over overlay here
	pass

## Highlight current player's row
func _highlight_current_player(player_index: int) -> void:
	for i in range(_player_rows.size()):
		var row = _player_rows[i]
		if row:
			var color_indicator = row.get_node_or_null("ColorIndicator")
			if color_indicator:
				if i == player_index:
					color_indicator.color = PLAYER_COLORS[i]
				else:
					color_indicator.color = PLAYER_COLORS[i].darkened(0.5)

## Get player color by index
func get_player_color(index: int) -> Color:
	if index >= 0 and index < PLAYER_COLORS.size():
		return PLAYER_COLORS[index]
	return Color.WHITE
