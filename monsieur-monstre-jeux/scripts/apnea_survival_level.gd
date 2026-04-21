extends Node2D

## Apnea Survival minigame controller.
## Players must stay underwater - surfacing = losing.
## Air depletes over time, bubbles restore air, fish damage players.

const OrganConst = preload("res://scripts/core/organ_constants.gd")
const PlayerData = preload("res://scripts/core/player_data.gd")

# Minigame state
enum GameState { WAITING, COUNTDOWN, PLAYING, FINISHED }
var game_state: GameState = GameState.WAITING

# Players
@onready var p1: Node2D = $P1
@onready var p2: Node2D = $P2

# Containers
@onready var fish_container: Node2D = $FishContainer
@onready var bubble_container: Node2D = $BubbleContainer

# UI References
@onready var status_label: Label = $CanvasLayer/HUD/StatusLabel
@onready var timer_label: Label = $CanvasLayer/HUD/TimerLabel
@onready var countdown_label: Label = $CanvasLayer/CountdownLabel
@onready var p1_air_bar: ProgressBar = $CanvasLayer/HUD/P1AirBar
@onready var p2_air_bar: ProgressBar = $CanvasLayer/HUD/P2AirBar
@onready var p1_status: Label = $CanvasLayer/HUD/P1Status
@onready var p2_status: Label = $CanvasLayer/HUD/P2Status
@onready var surface_line: Line2D = $SurfaceLine

# Level boundaries
@export var surface_y: float = 80.0
@export var level_bottom_y: float = 600.0
@export var level_width: float = 640.0

# Game settings
@export var duration: float = 60.0
@export var countdown_duration: float = 3.0

# Fish spawning
@export var fish_spawn_interval_min: float = 3.0
@export var fish_spawn_interval_max: float = 5.0
@export var max_fish_count: int = 6
var fish_spawn_timer: float = 0.0
var next_spawn_time: float = 3.0

# Bubble spawning
@export var bubble_spawn_interval: float = 2.0
var bubble_spawn_timer: float = 0.0

# Game timer
var game_timer: float = 0.0
var countdown_timer: float = 0.0

# Player data
var player1_data
var player2_data

# Elimination tracking
var p1_eliminated: bool = false
var p2_eliminated: bool = false

# Animation helper
var _animations: Node = null

# MinigameConnection reference for stake handling
var minigame_connection: Node = null

# Challenge stake information
var current_stake: Dictionary = {
	"organ_wagered": "",
	"stake_multiplier": 1.0,
	"player_index": -1
}

signal minigame_ended(winner_id: int)
signal minigame_result(player_index: int, success: bool, winner_id: int)

# Constants
const FISH_SCENE = preload("res://scenes/fish.tscn")

func _ready() -> void:
	_animations = get_node_or_null("/root/Animations")
	_setup_ui()
	_initialize_players()
	_setup_level()
	game_state = GameState.WAITING

func _setup_ui() -> void:
	if countdown_label:
		countdown_label.add_theme_font_size_override("font_size", 72)
		countdown_label.visible = false
	
	if status_label:
		status_label.text = "PRESS SPACE TO START"
		status_label.self_modulate = Color(1, 1, 1, 1)
	
	if surface_line:
		var points = [Vector2(0, surface_y), Vector2(level_width, surface_y)]
		surface_line.clear_points()
		for p in points:
			surface_line.add_point(p)
		surface_line.default_color = Color(0.3, 0.6, 1.0, 0.5)

func _initialize_players() -> void:
	var pd = get_node("/root/PlayerData")
	player1_data = pd
	player2_data = pd
	
	if p1 and p1.has_method("set_player_organs"):
		var organs_copy = player1_data.organs.duplicate() if player1_data and player1_data.has("organs") else {}
		p1.set_player_organs(organs_copy)
	
	if p2 and p2.has_method("set_player_organs"):
		var organs_copy = player2_data.organs.duplicate() if player2_data and player2_data.has("organs") else {}
		p2.set_player_organs(organs_copy)
	
	if p1 and p1.has_method("reset_for_new_game"):
		p1.reset_for_new_game()
	if p2 and p2.has_method("reset_for_new_game"):
		p2.reset_for_new_game()
	
	# Set level bounds for players
	if p1 and p1.has_method("set_level_bounds"):
		p1.set_level_bounds(surface_y, level_bottom_y, level_width)
	if p2 and p2.has_method("set_level_bounds"):
		p2.set_level_bounds(surface_y, level_bottom_y, level_width)
	
	# Starting positions
	p1.position = Vector2(150, level_bottom_y - 100)
	p2.position = Vector2(450, level_bottom_y - 100)

func _setup_level() -> void:
	pass

func _start_countdown() -> void:
	game_state = GameState.COUNTDOWN
	countdown_timer = countdown_duration
	countdown_label.visible = true
	countdown_label.text = "3"
	status_label.text = "Stay underwater!"
	p1_eliminated = false
	p2_eliminated = false

func _process(delta: float) -> void:
	match game_state:
		GameState.WAITING:
			_update_waiting_state()
		GameState.COUNTDOWN:
			_update_countdown(delta)
		GameState.PLAYING:
			_update_gameplay(delta)
		GameState.FINISHED:
			pass

func _update_waiting_state() -> void:
	var space_pressed = Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE)
	if space_pressed:
		_start_countdown()

func _update_countdown(delta: float) -> void:
	countdown_timer -= delta
	
	var seconds_left = ceil(countdown_timer)
	if seconds_left > 0:
		countdown_label.text = str(seconds_left)
	else:
		countdown_label.text = "DIVE!"
		if _animations:
			_animations.challenge_start_effect()
		_start_game()

func _start_game() -> void:
	game_state = GameState.PLAYING
	game_timer = 0.0
	countdown_label.visible = false
	status_label.text = "Don't surface!"
	fish_spawn_timer = 0.0
	next_spawn_time = randf_range(fish_spawn_interval_min, fish_spawn_interval_max)
	bubble_spawn_timer = 0.0
	
	# Reset player states
	if p1 and p1.has_method("reset_for_new_game"):
		p1.reset_for_new_game()
	if p2 and p2.has_method("reset_for_new_game"):
		p2.reset_for_new_game()

func _update_gameplay(delta: float) -> void:
	game_timer += delta
	
	var time_left = max(0, duration - game_timer)
	timer_label.text = "Time: %.1f" % time_left
	
	# Timer urgency
	if time_left <= 10.0 and _animations:
		_animations.timer_urgent(timer_label)
	
	# Update player states
	_update_player(p1, 1, delta)
	_update_player(p2, 2, delta)
	
	# Update air bars
	if p1 and p1.has_method("get_air_level"):
		p1_air_bar.value = p1.get_air_level()
	if p2 and p2.has_method("get_air_level"):
		p2_air_bar.value = p2.get_air_level()
	
	# Check surfacing and eliminations
	_check_surfacing()
	_check_fish_collision()
	_check_eliminations()
	
	# Spawn management
	_update_spawning(delta)
	
	# Check win conditions
	_check_win_conditions()
	
	if game_timer >= duration:
		_end_game(_determine_winner())

func _update_player(player: Node2D, player_id: int, delta: float) -> void:
	if not player:
		return
	
	# Check if player is eliminated
	var is_eliminated = false
	if player_id == 1:
		is_eliminated = p1_eliminated
	else:
		is_eliminated = p2_eliminated
	
	if is_eliminated:
		if player.has_method("set_eliminated"):
			player.set_eliminated(true)
		return
	
	# Update player HUD status
	var status_text = "OK"
	if player.has_method("get_damage_count"):
		var damage = player.get_damage_count()
		if damage > 0:
			status_text = "Hit %d/2" % damage
	if player_id == 1:
		p1_status.text = status_text
	else:
		p2_status.text = status_text

func _check_surfacing() -> void:
	# Check if players have surfaced (gone above water line)
	if p1 and not p1_eliminated:
		if p1.position.y < surface_y:
			if p1.has_method("has_surfaced") and not p1.has_surfaced():
				p1_eliminated = true
				_emit_elimination(1, "surfaced")
	
	if p2 and not p2_eliminated:
		if p2.position.y < surface_y:
			if p2.has_method("has_surfaced") and not p2.has_surfaced():
				p2_eliminated = true
				_emit_elimination(2, "surfaced")

func _check_fish_collision() -> void:
	if not fish_container:
		return
	
	for fish in fish_container.get_children():
		if not fish.has_method("get_bounds"):
			continue
		
		var fish_pos = fish.global_position
		var fish_bounds = fish.get_bounds()
		
		# Check P1 collision
		if p1 and not p1_eliminated:
			var p1_pos = p1.global_position
			if _is_collision(p1_pos, fish_pos, fish_bounds, 30.0):
				if p1.has_method("take_damage"):
					p1.take_damage()
		
		# Check P2 collision
		if p2 and not p2_eliminated:
			var p2_pos = p2.global_position
			if _is_collision(p2_pos, fish_pos, fish_bounds, 30.0):
				if p2.has_method("take_damage"):
					p2.take_damage()

func _is_collision(pos1: Vector2, pos2: Vector2, bounds: Vector2, radius: float) -> bool:
	var dx = abs(pos1.x - pos2.x)
	var dy = abs(pos1.y - pos2.y)
	return dx < bounds.x + radius and dy < bounds.y + radius

func _emit_elimination(player_id: int, reason: String) -> void:
	print("[ApneaSurvival] Player %d eliminated: %s" % [player_id, reason])
	if reason == "surfaced":
		status_label.text = "P%d surfaced! Eliminated!" % player_id
		status_label.self_modulate = Color(1, 0.3, 0.3, 1)

func _check_eliminations() -> void:
	# Check for fish damage eliminations
	if p1 and p1.has_method("get_damage_count") and p1.get_damage_count() >= 2 and not p1_eliminated:
		p1_eliminated = true
		_emit_elimination(1, "fish_damage")
	
	if p2 and p2.has_method("get_damage_count") and p2.get_damage_count() >= 2 and not p2_eliminated:
		p2_eliminated = true
		_emit_elimination(2, "fish_damage")

func _update_spawning(delta: float) -> void:
	# Spawn fish
	fish_spawn_timer += delta
	if fish_spawn_timer >= next_spawn_time and fish_container.get_child_count() < max_fish_count:
		_spawn_fish()
		fish_spawn_timer = 0.0
		next_spawn_time = randf_range(fish_spawn_interval_min, fish_spawn_interval_max)
	
	# Spawn bubbles
	bubble_spawn_timer += delta
	if bubble_spawn_timer >= bubble_spawn_interval:
		_spawn_bubble()
		bubble_spawn_timer = 0.0

func _spawn_fish() -> void:
	if not fish_container:
		return
	
	var fish = FISH_SCENE.instantiate()
	
	# Random position
	var spawn_y = randf_range(surface_y + 50, level_bottom_y - 50)
	var spawn_x = randf_range(50, level_width - 50)
	fish.position = Vector2(spawn_x, spawn_y)
	
	# Random direction and speed
	var direction = 1 if randf() > 0.5 else -1
	fish.speed = randf_range(100, 150)
	fish.direction = direction
	
	fish_container.add_child(fish)
	print("[ApneaSurvival] Spawned fish at", fish.position)

func _spawn_bubble() -> void:
	if not bubble_container:
		return
	
	# Create bubble via GDScript directly
	var bubble = load("res://scripts/bubble.gd").new()
	
	# Random position
	var spawn_x = randf_range(50, level_width - 50)
	var spawn_y = randf_range(surface_y + 30, level_bottom_y - 30)
	bubble.position = Vector2(spawn_x, spawn_y)
	
	# Configure bubble
	if bubble.has_method("set_spawn_position"):
		bubble.set_spawn_position(spawn_x, spawn_y, surface_y, level_bottom_y)
	
	bubble_container.add_child(bubble)
	print("[ApneaSurvival] Spawned bubble at", bubble.position)

func _check_win_conditions() -> void:
	# If one player eliminated but not the other, remaining player wins
	if p1_eliminated and not p2_eliminated:
		_end_game(2)
	elif p2_eliminated and not p1_eliminated:
		_end_game(1)
	# Both eliminated at same time
	elif p1_eliminated and p2_eliminated:
		_end_game(0)

func _determine_winner() -> int:
	# If we get here, time ran out - check who has more air
	var p1_air = p1.get_air_level() if p1 and p1.has_method("get_air_level") else 0
	var p2_air = p2.get_air_level() if p2 and p2.has_method("get_air_level") else 0
	
	if p1_air > p2_air:
		return 1
	elif p2_air > p1_air:
		return 2
	else:
		return 0

func _end_game(winner_id: int) -> void:
	game_state = GameState.FINISHED
	
	var result_text = ""
	var result_color = Color.WHITE
	
	if winner_id > 0:
		result_text = "Player %d Wins!" % winner_id
		result_color = Color(0.2, 0.8, 0.2)
	elif winner_id == 0:
		result_text = "It's a Tie!"
		result_color = Color(0.8, 0.8, 0.2)
	else:
		result_text = "No Winner!"
		result_color = Color(0.8, 0.2, 0.2)
	
	status_label.text = result_text
	countdown_label.text = result_text
	countdown_label.visible = true
	countdown_label.self_modulate = result_color
	
	if _animations:
		if winner_id > 0:
			_animations.win_text(countdown_label, 2.0)
		else:
			_animations.lose_text(countdown_label, 2.0)
	
	emit_signal("minigame_result", current_stake.get("player_index", -1), winner_id > 0, winner_id)
	
	await get_tree().create_timer(3.0).timeout
	minigame_ended.emit(winner_id)

func set_stake(player_index: int, organ_wagered: String, multiplier: float = 1.0) -> void:
	current_stake = {
		"player_index": player_index,
		"organ_wagered": organ_wagered,
		"stake_multiplier": multiplier
	}

func get_stake() -> Dictionary:
	return current_stake.duplicate(true)

func start_game_with_stake(player_index: int, organ_wagered: String, multiplier: float = 1.0) -> void:
	set_stake(player_index, organ_wagered, multiplier)
	_start_countdown()

func force_start() -> void:
	_start_countdown()