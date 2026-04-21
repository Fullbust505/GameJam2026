extends Control

# Board Display for Monsieur Monstre - Visualizes the game board with tiles and player positions

# Tile type to icon mapping (using existing sprite assets where possible)
const TILE_ICONS: Dictionary = {
	"SHOP": "res://assets/sprites/shop.png",
	"CHALLENGE": "res://assets/sprites/teeth.png",  # skull-like for challenge
	"STEAL": "res://assets/sprites/geiger_hand.png",  # hand for steal
	"SWAP": "res://assets/sprites/geiger_hand.png",  # reuse hand for swap
	"BONUS": "res://assets/sprites/heart.png",  # heart for bonus/good
	"PENALTY": "res://assets/sprites/warning.png",  # warning for penalty
	"EVENT": "res://assets/sprites/eye.png",  # eye for mystery/event
	"START": "res://assets/sprites/heart.png"  # heart for start
}

# Tile colors for visual distinction
const TILE_COLORS: Dictionary = {
	"SHOP": Color(0.3, 0.5, 0.8),      # Blue
	"CHALLENGE": Color(0.8, 0.2, 0.2), # Red
	"STEAL": Color(0.6, 0.3, 0.6),    # Purple
	"SWAP": Color(0.5, 0.5, 0.3),     # Olive
	"BONUS": Color(0.2, 0.7, 0.3),    # Green
	"PENALTY": Color(0.8, 0.5, 0.1),   # Orange
	"EVENT": Color(0.4, 0.2, 0.6),     # Violet
	"START": Color(0.9, 0.7, 0.1)      # Gold
}

# Constants
const TILE_SIZE: Vector2 = Vector2(80, 80)
const PLAYER_TOKEN_SIZE: Vector2 = Vector2(30, 30)
const BOARD_PADDING: float = 60.0

# State
var _board_tiles: Array = []
var _player_positions: Array = []
var _tile_nodes: Array = []  # Array of tile Control nodes
var _player_tokens: Array = []  # Array of player token nodes
var _highlighted_tile_index: int = -1

# Signals
signal tile_clicked(tile_index: int)
signal tile_hovered(tile_index: int)

# Called when the node enters the scene tree
func _ready() -> void:
	# Initialize empty
	pass

# Setup the board with tiles and player positions
# board_tiles: Array of Tile objects from BoardGenerator
# player_positions: Array of player board positions (integers)
func setup(board_tiles: Array, player_positions: Array) -> void:
	_board_tiles = board_tiles
	_player_positions = player_positions
	
	# Clear existing tiles
	_clear_tiles()
	
	# Create tile nodes
	_create_tiles()
	
	# Create player tokens
	_create_player_tokens()
	
	# Layout the board
	_layout_board()

# Clear all tile and player token nodes
func _clear_tiles() -> void:
	for node in _tile_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_tile_nodes.clear()
	
	for node in _player_tokens:
		if is_instance_valid(node):
			node.queue_free()
	_player_tokens.clear()
	
	_highlighted_tile_index = -1

# Create tile visual nodes
func _create_tiles() -> void:
	for i in range(_board_tiles.size()):
		var tile = _board_tiles[i]
		var tile_type_str = _get_tile_type_string(tile.tile_type)
		
		# Create tile container
		var tile_container = _create_tile_node(i, tile_type_str)
		_tile_nodes.append(tile_container)
		add_child(tile_container)

# Create a single tile node
func _create_tile_node(index: int, tile_type_str: String) -> Control:
	var container = Control.new()
	container.name = "Tile_" + str(index)
	container.custom_minimum_size = TILE_SIZE
	
	# Create background
	var bg = ColorRect.new()
	bg.color = TILE_COLORS.get(tile_type_str, Color.GRAY)
	bg.custom_minimum_size = TILE_SIZE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(bg)
	
	# Create icon
	var icon = TextureRect.new()
	icon.expand = true
	icon.custom_minimum_size = Vector2(40, 40)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var icon_path = TILE_ICONS.get(tile_type_str, "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	else:
		# Create a fallback label if no icon
		var label = Label.new()
		label.text = tile_type_str.substr(0, 1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.add_child(label)
	
	icon.set_anchors_preset(Control.PRESET_CENTER)
	container.add_child(icon)
	
	# Create position label (tile number)
	var pos_label = Label.new()
	pos_label.text = str(index)
	pos_label.add_theme_font_size_override("font_size", 12)
	pos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pos_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	pos_label.anchor_top = 1.0
	pos_label.anchor_bottom = 1.0
	pos_label.offset_top = -20
	pos_label.offset_bottom = -5
	pos_label.offset_left = 0
	pos_label.offset_right = 0
	container.add_child(pos_label)
	
	# Add hover/click signals
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var tile_index = index  # Capture for closure
	container.mouse_entered.connect(_on_tile_mouse_entered.bind(tile_index))
	container.mouse_exited.connect(_on_tile_mouse_exited.bind(tile_index))
	
	return container

# Create player token nodes
func _create_player_tokens() -> void:
	for i in range(_player_positions.size()):
		var token = _create_player_token_node(i)
		_player_tokens.append(token)
		add_child(token)

# Create a player token (colored circle with number)
func _create_player_token_node(player_index: int) -> Control:
	var container = Control.new()
	container.name = "PlayerToken_" + str(player_index)
	container.custom_minimum_size = PLAYER_TOKEN_SIZE
	
	# Create background circle using a rounded RectangleShape2D in a CollisionShape2D
	# For simplicity, just use a ColorRect with the player color
	var circle = ColorRect.new()
	circle.color = _get_player_color(player_index)
	circle.custom_minimum_size = PLAYER_TOKEN_SIZE
	circle.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(circle)
	
	# Add player number
	var label = Label.new()
	label.text = str(player_index + 1)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(label)
	
	# Make it appear above tiles
	container.z_index = 100
	
	return container

# Get player color based on index
func _get_player_color(player_index: int) -> Color:
	var colors = [
		Color(0.2, 0.6, 0.9),   # Blue
		Color(0.9, 0.3, 0.3),   # Red
		Color(0.3, 0.8, 0.3),   # Green
		Color(0.9, 0.7, 0.2)    # Yellow
	]
	return colors[player_index % colors.size()]

# Layout tiles in a circular/oval arrangement
func _layout_board() -> void:
	var board_size = _board_tiles.size()
	if board_size == 0:
		return
	
	# Calculate center and radius for oval layout
	var center = get_viewport_rect().size / 2
	var size = get_viewport_rect().size
	
	# Adjust for padding
	var available_width = size.x - BOARD_PADDING * 2
	var available_height = size.y - BOARD_PADDING * 2
	
	# Determine radius based on board size
	var base_radius = min(available_width, available_height) / 2 - TILE_SIZE.x
	var radius_x = base_radius
	var radius_y = base_radius * 0.7  # Slightly oval
	
	# Position tiles in a circle
	for i in range(_tile_nodes.size()):
		if i < _tile_nodes.size():
			var angle = (2.0 * PI * i / board_size) - (PI / 2)  # Start from top
			var x = center.x + cos(angle) * radius_x - TILE_SIZE.x / 2
			var y = center.y + sin(angle) * radius_y - TILE_SIZE.y / 2
			
			_tile_nodes[i].position = Vector2(x, y)
	
	# Position player tokens on their tiles
	_update_player_token_positions()
	
	# Scale the whole board to fit
	_scale_board_to_fit()

# Scale the board to fit within the viewport
func _scale_board_to_fit() -> void:
	# Calculate bounding box of all tiles
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	
	for tile in _tile_nodes:
		if is_instance_valid(tile):
			min_pos = min_pos.min(tile.position)
			max_pos = max_pos.max(tile.position + TILE_SIZE)
	
	var board_size = max_pos - min_pos
	var viewport_size = get_viewport_rect().size
	var scale_factor = min(viewport_size.x / board_size.x, viewport_size.y / board_size.y) * 0.9
	
	if scale_factor < 1.0:
		# Apply scale to a container or adjust positions
		# For simplicity, we just ensure tiles are visible within viewport
		pass

# Update player token positions based on current board positions
func _update_player_token_positions() -> void:
	for i in range(_player_tokens.size()):
		if i < _player_positions.size() and i < _tile_nodes.size():
			var tile_index = _player_positions[i]
			if tile_index >= 0 and tile_index < _tile_nodes.size():
				var tile_pos = _tile_nodes[tile_index].position
				# Offset token within the tile
				var token_offset = _get_player_token_offset(i)
				_player_tokens[i].position = tile_pos + token_offset

# Get offset for player token to avoid stacking
func _get_player_token_offset(player_index: int) -> Vector2:
	# Stack tokens slightly offset from each other
	var offset_angle = player_index * (PI / 4)
	var offset_dist = 10.0
	return Vector2(
		cos(offset_angle) * offset_dist + TILE_SIZE.x / 2 - PLAYER_TOKEN_SIZE.x / 2,
		sin(offset_angle) * offset_dist + TILE_SIZE.y / 2 - PLAYER_TOKEN_SIZE.y / 2
	)

# Update a single player's position
func update_player_position(player_index: int, tile_index: int) -> void:
	if player_index < _player_positions.size():
		_player_positions[player_index] = tile_index
		_update_player_token_positions()

# Highlight a specific tile
func highlight_tile(tile_index: int) -> void:
	# Remove previous highlight
	if _highlighted_tile_index >= 0 and _highlighted_tile_index < _tile_nodes.size():
		var prev_tile = _tile_nodes[_highlighted_tile_index]
		if is_instance_valid(prev_tile):
			_set_tile_border_color(prev_tile, Color.TRANSPARENT)
	
	_highlighted_tile_index = tile_index
	
	# Apply new highlight
	if tile_index >= 0 and tile_index < _tile_nodes.size():
		var tile = _tile_nodes[tile_index]
		if is_instance_valid(tile):
			_set_tile_border_color(tile, Color.YELLOW)
			# Animate highlight
			_animate_tile_highlight(tile)

# Set border color on a tile (adds a border if needed)
func _set_tile_border_color(tile: Control, color: Color) -> void:
	# Find or create border
	var border = tile.get_node_or_null("Border")
	if border == null:
		border = ColorRect.new()
		border.name = "Border"
		border.color = color
		border.set_anchors_preset(Control.PRESET_FULL_RECT)
		border.z_index = -1
		tile.add_child(border)
	else:
		border.color = color

# Animate tile highlight (pulse effect)
func _animate_tile_highlight(tile: Control) -> void:
	# Simple scale animation
	var tween = create_tween()
	tween.tween_property(tile, "scale", Vector2(1.1, 1.1), 0.15)
	tween.tween_property(tile, "scale", Vector2(1.0, 1.0), 0.15)

# Get tile at a given viewport position (for click detection)
func get_tile_at_position(pos: Vector2) -> int:
	# Check tiles in reverse order (topmost first)
	for i in range(_tile_nodes.size() - 1, -1, -1):
		var tile = _tile_nodes[i]
		if is_instance_valid(tile):
			var tile_rect = Rect2(tile.position, TILE_SIZE)
			if tile_rect.has_point(pos):
				return i
	return -1  # No tile at position

# Handle tile click (emit signal with tile index)
func _on_tile_clicked(tile_index: int) -> void:
	emit_signal("tile_clicked", tile_index)

# Mouse entered tile
func _on_tile_mouse_entered(tile_index: int) -> void:
	emit_signal("tile_hovered", tile_index)
	# Optional: show tooltip or highlight

# Mouse exited tile
func _on_tile_mouse_exited(tile_index: int) -> void:
	pass

# Input handler for click detection
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var tile_index = get_tile_at_position(event.position)
			if tile_index >= 0:
				_on_tile_clicked(tile_index)

# Convert tile type enum to string
func _get_tile_type_string(tile_type: int) -> String:
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

# Get tile type string for external use
func get_tile_type_name(tile_index: int) -> String:
	if tile_index >= 0 and tile_index < _board_tiles.size():
		var tile = _board_tiles[tile_index]
		return _get_tile_type_string(tile.tile_type)
	return "UNKNOWN"

# Get tile data (properties) for a given tile index
func get_tile_data(tile_index: int) -> Dictionary:
	if tile_index >= 0 and tile_index < _board_tiles.size():
		var tile = _board_tiles[tile_index]
		return tile.properties
	return {}

# Animate player movement from one tile to another
func animate_player_move(player_index: int, from_tile: int, to_tile: int, duration: float = 0.5) -> void:
	if player_index >= _player_tokens.size():
		return
	
	var token = _player_tokens[player_index]
	if not is_instance_valid(token):
		return
	
	var start_pos = Vector2.ZERO
	var end_pos = Vector2.ZERO
	
	# Get start position from tile
	if from_tile >= 0 and from_tile < _tile_nodes.size():
		start_pos = _tile_nodes[from_tile].position + _get_player_token_offset(player_index)
	else:
		start_pos = token.position
	
	# Get end position from tile
	if to_tile >= 0 and to_tile < _tile_nodes.size():
		end_pos = _tile_nodes[to_tile].position + _get_player_token_offset(player_index)
	
	# Animate the movement
	var tween = create_tween()
	token.position = start_pos
	tween.tween_property(token, "position", end_pos, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	
	# Update player position at the end
	await tween.finished
	_player_positions[player_index] = to_tile

# Refresh the entire board layout (call on resize)
func refresh_layout() -> void:
	_layout_board()

# Get number of tiles
func get_tile_count() -> int:
	return _board_tiles.size()

# Get current player position
func get_player_position(player_index: int) -> int:
	if player_index >= 0 and player_index < _player_positions.size():
		return _player_positions[player_index]
	return -1