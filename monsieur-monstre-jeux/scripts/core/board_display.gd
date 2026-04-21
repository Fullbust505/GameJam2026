extends Control

# Board Display for Monsieur Monstre - Visualizes the game board with tiles, path, and player positions

# Animation helper reference
var _animations: Node = null

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
const TILE_SIZE: Vector2 = Vector2(36, 36)  # Smaller tiles for circular layout
const PLAYER_TOKEN_SIZE: Vector2 = Vector2(20, 20)
const BOARD_PADDING: float = 80.0
const PATH_LINE_WIDTH: float = 3.0

# State
var _board_tiles: Array = []
var _player_positions: Array = []
var _tile_nodes: Array = []  # Array of tile Control nodes
var _player_tokens: Array = []  # Array of player token nodes
var _path_lines: Array = []  # Line2D nodes for path connections
var _path_container: Node = null  # Container for path lines
var _highlighted_tile_index: int = -1

# Signals
signal tile_clicked(tile_index: int)
signal tile_hovered(tile_index: int)

# Called when the node enters the scene tree
func _ready() -> void:
	# Get animations helper
	_animations = get_node_or_null("/root/Animations")
	
	# Create path container for Line2D nodes
	_path_container = Node.new()
	_path_container.name = "PathContainer"
	add_child(_path_container)
	
	# Connect to window resize to refresh layout when viewport changes
	get_viewport().size_changed.connect(_on_viewport_size_changed)

# Handle viewport size changes (window resize)
func _on_viewport_size_changed() -> void:
	# Re-layout board when window is resized
	if _board_tiles.size() > 0:
		_layout_board()

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
	
	# Create path connections between tiles
	_create_path_lines()
	
	# Create player tokens
	_create_player_tokens()
	
	# Layout the board - use call_deferred to ensure we're in the tree
	call_deferred("_do_layout_board")

## Layout the board - called deferred to ensure node is in tree
func _do_layout_board() -> void:
	if is_inside_tree():
		_layout_board()

## Show board with entrance animation
func show_board_animated() -> void:
	visible = true
	if _animations and _tile_nodes.size() > 0:
		_animations.board_entrance(_tile_nodes, 0.08)
	else:
		visible = true
		for tile in _tile_nodes:
			if is_instance_valid(tile):
				tile.scale = Vector2.ONE

## Hide board with exit animation
func hide_board_animated() -> void:
	if _animations:
		for tile in _tile_nodes:
			if is_instance_valid(tile):
				var tween = tile.create_tween()
				tween.tween_property(tile, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
		await get_tree().create_timer(0.3).timeout
	visible = false

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
	
	for node in _path_lines:
		if is_instance_valid(node):
			node.queue_free()
	_path_lines.clear()
	
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

# Create a single tile node - circular colored rect with icon
func _create_tile_node(index: int, tile_type_str: String) -> Control:
	var container = Control.new()
	container.name = "Tile_" + str(index)
	container.custom_minimum_size = TILE_SIZE
	container.z_index = 10  # Above path lines
	
	# Create circular background using ColorRect with a Panel-style look
	var bg = Panel.new()
	bg.custom_minimum_size = TILE_SIZE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Set the panel's background color
	var style = StyleBoxFlat.new()
	style.bg_color = TILE_COLORS.get(tile_type_str, Color.GRAY)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.set_border_width_all(2)
	style.border_color = TILE_COLORS.get(tile_type_str, Color.GRAY).darkened(0.3)
	bg.add_theme_stylebox_override("panel", style)
	
	container.add_child(bg)
	
	# Create icon
	var icon = TextureRect.new()
	icon.expand = true
	icon.custom_minimum_size = Vector2(20, 20)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var icon_path = TILE_ICONS.get(tile_type_str, "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	
	icon.set_anchors_preset(Control.PRESET_CENTER)
	container.add_child(icon)
	
	# Create position label (tile number) - small at bottom
	var pos_label = Label.new()
	pos_label.text = str(index)
	pos_label.add_theme_font_size_override("font_size", 10)
	pos_label.add_theme_color_override("font_color", Color.WHITE)
	pos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pos_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	pos_label.anchor_top = 1.0
	pos_label.anchor_bottom = 1.0
	pos_label.offset_top = -14
	pos_label.offset_bottom = -4
	pos_label.offset_left = 0
	pos_label.offset_right = 0
	container.add_child(pos_label)
	
	# Add hover/click signals
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var tile_index = index  # Capture for closure
	container.mouse_entered.connect(_on_tile_mouse_entered.bind(tile_index))
	container.mouse_exited.connect(_on_tile_mouse_exited.bind(tile_index))
	
	return container

# Create path lines connecting consecutive tiles
func _create_path_lines() -> void:
	if _board_tiles.size() < 2:
		return
	
	# Create a single Line2D that draws the path through all tiles
	var path_line = Line2D.new()
	path_line.name = "BoardPath"
	path_line.width = PATH_LINE_WIDTH
	path_line.default_color = Color(0.5, 0.5, 0.5, 0.8)  # Gray path line
	path_line.joint_mode = Line2D.LINE_JOINT_ROUND
	path_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	path_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	path_line.z_index = 5  # Below tiles
	
	_path_lines.append(path_line)
	var parent = _path_container
	if parent:
		parent.add_child(path_line)
	else:
		var tree = get_tree()
		if tree:
			tree.root.add_child(path_line)
		# else: do nothing, will be called later when properly in tree
	
	# Points will be set in _layout_board() once we know positions

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
	container.z_index = 100  # Above tiles
	
	# Create circular background using Panel with rounded style
	var circle = Panel.new()
	circle.custom_minimum_size = PLAYER_TOKEN_SIZE
	circle.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var style = StyleBoxFlat.new()
	style.bg_color = _get_player_color(player_index)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.set_border_width_all(2)
	style.border_color = _get_player_color(player_index).darkened(0.3)
	circle.add_theme_stylebox_override("panel", style)
	
	container.add_child(circle)
	
	# Add player number
	var label = Label.new()
	label.text = str(player_index + 1)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(label)
	
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
	
	# Guard against being called before node is in scene tree
	if not is_inside_tree():
		return
	
	# Use the Control's own size instead of viewport size
	var rect = get_rect()
	var center = rect.size / 2
	var size = rect.size
	
	# Adjust for padding
	var available_width = size.x - BOARD_PADDING * 2
	var available_height = size.y - BOARD_PADDING * 2
	
	# Determine radius based on board size - tiles should fit nicely in a circle
	var base_radius = min(available_width, available_height) / 2 - TILE_SIZE.x
	var radius_x = base_radius
	var radius_y = base_radius * 0.7  # Slightly oval
	
	# Calculate tile positions first
	var tile_positions: Array = []
	for i in range(_tile_nodes.size()):
		if i < _tile_nodes.size():
			var angle = (2.0 * PI * i / board_size) - (PI / 2)  # Start from top
			var x = center.x + cos(angle) * radius_x - TILE_SIZE.x / 2
			var y = center.y + sin(angle) * radius_y - TILE_SIZE.y / 2
			
			_tile_nodes[i].position = Vector2(x, y)
			tile_positions.append(Vector2(x + TILE_SIZE.x / 2, y + TILE_SIZE.y / 2))
	
	# Update path lines to connect tiles in order
	_update_path_lines(tile_positions)
	
	# Position player tokens on their tiles
	_update_player_token_positions()

# Update path line points to connect tiles in order
func _update_path_lines(tile_positions: Array) -> void:
	if _path_lines.size() > 0 and tile_positions.size() > 0:
		var path_line = _path_lines[0]
		path_line.clear_points()
		for pos in tile_positions:
			path_line.add_point(pos)
		# Close the loop back to first tile
		if tile_positions.size() > 1:
			path_line.add_point(tile_positions[0])

# Update player token positions based on current board positions
func _update_player_token_positions() -> void:
	for i in range(_player_tokens.size()):
		if i < _player_positions.size() and i < _tile_nodes.size():
			var tile_index = _player_positions[i]
			if tile_index >= 0 and tile_index < _tile_nodes.size():
				var tile_pos = _tile_nodes[tile_index].position
				# Center token on the tile
				_player_tokens[i].position = tile_pos + (TILE_SIZE - PLAYER_TOKEN_SIZE) / 2

# Update a single player's position
func update_player_position(player_index: int, tile_index: int) -> void:
	if player_index < _player_positions.size():
		_player_positions[player_index] = tile_index
		_update_player_token_positions()

## Apply penalty effect to a tile (shake)
func apply_penalty_effect(tile_index: int) -> void:
	if tile_index >= 0 and tile_index < _tile_nodes.size():
		var tile = _tile_nodes[tile_index]
		if is_instance_valid(tile) and _animations:
			_animations.penalty_shake(tile)

## Get the animations helper
func get_animations() -> Node:
	return _animations

# Highlight a specific tile
func highlight_tile(tile_index: int) -> void:
	# Remove previous highlight
	if _highlighted_tile_index >= 0 and _highlighted_tile_index < _tile_nodes.size():
		var prev_tile = _tile_nodes[_highlighted_tile_index]
		if is_instance_valid(prev_tile):
			_set_tile_border_color(prev_tile, Color.TRANSPARENT)
			# Stop pulse animation
			if prev_tile.has_method("stop"):
				prev_tile.stop_all_tweens()
			prev_tile.scale = Vector2.ONE
	
	_highlighted_tile_index = tile_index
	
	# Apply new highlight
	if tile_index >= 0 and tile_index < _tile_nodes.size():
		var tile = _tile_nodes[tile_index]
		if is_instance_valid(tile):
			_set_tile_border_color(tile, Color.YELLOW)
			# Animate highlight with pulse
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
	# Use animations helper for smooth pulse
	if _animations:
		_animations.tile_pulse(tile, 1.2)
	else:
		# Fallback: simple scale animation
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
		start_pos = _tile_nodes[from_tile].position + (TILE_SIZE - PLAYER_TOKEN_SIZE) / 2
	else:
		start_pos = token.position
	
	# Get end position from tile
	if to_tile >= 0 and to_tile < _tile_nodes.size():
		end_pos = _tile_nodes[to_tile].position + (TILE_SIZE - PLAYER_TOKEN_SIZE) / 2
	
	# Use animations helper for smooth movement
	if _animations:
		_animations.animate_token_move(token, start_pos, end_pos, duration)
	else:
		# Fallback: direct tween
		var tween = create_tween()
		token.position = start_pos
		tween.tween_property(token, "position", end_pos, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	
	# Update player position at the end
	_player_positions[player_index] = to_tile
	
	# Bounce token on landing
	if to_tile >= 0 and to_tile < _tile_nodes.size():
		var target_tile = _tile_nodes[to_tile]
		if _animations and is_instance_valid(target_tile):
			await get_tree().create_timer(duration).timeout
			_animations.token_land_bounce(token)

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
