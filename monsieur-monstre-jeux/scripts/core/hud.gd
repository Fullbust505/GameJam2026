extends Control

## Score/Organs HUD for Monsieur Monstre board game
## Displays player stats including money, score, and owned organs

signal setup_complete

var _game_state = null
var _player_panels: Array = []
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

# Map organ type to scene node name
const ORGAN_NODE_NAMES: Dictionary = {
	0: "OrganBrain",
	1: "OrganHeart",
	2: "OrganLungs",
	3: "OrganArms",
	4: "OrganLegs",
	5: "OrganEyes",
	6: "OrganPancreas",
	7: "OrganLiver",
	8: "OrganKidneys"
}

# Organ display order
const ORGAN_DISPLAY_ORDER: Array = [1, 5, 3, 4, 2, 6, 7, 8, 0]  # HEART, EYES, ARMS, LEGS, LUNGS, PANCREAS, LIVER, KIDNEYS, BRAIN

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
	
	# Store references to player panels
	_player_panels = []
	for i in range(4):  # Support up to 4 players
		var panel = get_node_or_null("PlayerContainer/PlayerPanel%d" % i)
		if panel:
			_player_panels.append(panel)
	
	refresh()
	setup_complete.emit()

## Refresh all display values
func refresh() -> void:
	if not _game_state:
		return
	
	var num_players = _game_state.max_players
	
	# Update each player's display
	for i in range(num_players):
		if i < _player_panels.size():
			_update_player_display(i)

## Update display for a specific player
func _update_player_display(player_index: int) -> void:
	if not _game_state or player_index >= _game_state.players.size():
		return
	
	var player = _game_state.players[player_index]
	if not player:
		return
	
	var panel = _player_panels[player_index]
	if not panel:
		return
	
	# Update name label
	var name_label = panel.get_node_or_null("VBox/NameLabel")
	if name_label:
		name_label.text = "Player %d" % (player_index + 1)
	
	# Update money label
	var money_label = panel.get_node_or_null("VBox/MoneyLabel")
	if money_label:
		money_label.text = "$%d" % player.money
	
	# Update score label
	var score_label = panel.get_node_or_null("VBox/ScoreLabel")
	if score_label:
		score_label.text = "Score: %d" % player.score
	
	# Update organ icons
	_update_organ_display(player_index, player)

## Update organ display for a player
func _update_organ_display(player_index: int, player) -> void:
	var panel = _player_panels[player_index]
	if not panel:
		return
	
	var organs_grid = panel.get_node_or_null("VBox/OrgansGrid")
	if not organs_grid:
		return
	
	for organ_type in ORGAN_DISPLAY_ORDER:
		var count = player.get_organ_count(organ_type)
		var node_name = ORGAN_NODE_NAMES.get(organ_type, "")
		var organ_container = organs_grid.get_node_or_null(node_name)
		
		if organ_container:
			# Show/hide based on count
			organ_container.visible = count > 0
			
			# Update sprite if count > 0
			var sprite = organ_container.get_node_or_null("Sprite")
			if sprite and count > 0:
				var sprite_path = ORGAN_SPRITES.get(organ_type, "")
				if sprite_path != "" and ResourceLoader.exists(sprite_path):
					sprite.texture = load(sprite_path)
				else:
					sprite.texture = null
			
			# Update count label
			var count_label = organ_container.get_node_or_null("CountLabel")
			if count_label:
				count_label.text = "x%d" % count if count > 1 else ""

## Highlight current player's section
func _highlight_current_player(player_index: int) -> void:
	for i in range(_player_panels.size()):
		var panel = _player_panels[i]
		if panel:
			var color_rect = panel.get_node_or_null("ColorIndicator")
			if color_rect:
				if i == player_index:
					color_rect.color = PLAYER_COLORS[i]
				else:
					color_rect.color = Color(0.3, 0.3, 0.3, 0.5)

# Signal handlers
func _on_turn_changed(player_index: int) -> void:
	_current_player_index = player_index
	_highlight_current_player(player_index)

func _on_score_updated(player_id: int, new_score: int) -> void:
	if player_id < _player_panels.size():
		var panel = _player_panels[player_id]
		var score_label = panel.get_node_or_null("VBox/ScoreLabel")
		if score_label:
			# Get old value for animation
			var old_text = score_label.text
			var old_value = 0
			if "Score: " in old_text:
				old_value = int(old_text.split(": ")[1])
			
			# Animate the number change
			if _animations:
				_animations.score_tick(score_label, old_value, new_score)
			else:
				score_label.text = "Score: %d" % new_score

func _on_money_updated(player_id: int, new_money: int) -> void:
	if player_id < _player_panels.size():
		var panel = _player_panels[player_id]
		var money_label = panel.get_node_or_null("VBox/MoneyLabel")
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
	if player_id < _player_panels.size() and _game_state and player_id < _game_state.players.size():
		var player = _game_state.players[player_id]
		_update_organ_display(player_id, player)
		
		# Animate organ icon bounce
		if _animations and player_id < _player_panels.size():
			var organ_node_name = ORGAN_NODE_NAMES.get(organ_type, "")
			if organ_node_name != "":
				var panel = _player_panels[player_id]
				var organs_grid = panel.get_node_or_null("VBox/OrgansGrid")
				if organs_grid:
					var organ_container = organs_grid.get_node_or_null(organ_node_name)
					if organ_container:
						_animations.organ_bounce(organ_container)

func _on_game_ended(winner_id: int) -> void:
	# Could show a game over overlay here
	pass

## Get player color by index
func get_player_color(index: int) -> Color:
	if index >= 0 and index < PLAYER_COLORS.size():
		return PLAYER_COLORS[index]
	return Color.WHITE