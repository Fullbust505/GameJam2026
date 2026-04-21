extends Node2D

## Swimming minigame level controller.
## Manages players, UI, game state, and win/lose conditions.

const OrganConst = preload("res://scripts/core/organ_constants.gd")
const PlayerData = preload("res://scripts/core/player_data.gd")

# Minigame state
enum GameState { WAITING, COUNTDOWN, PLAYING, FINISHED }
var game_state: GameState = GameState.WAITING

# Players
@onready var p1: Node2D = $P1
@onready var p2: Node2D = $P2

# UI References from scene
@onready var control_panel: Panel = $CanvasLayer/ControlPanel
@onready var status_label: Label = $CanvasLayer/ControlPanel/Status
@onready var timer_label: Label = $CanvasLayer/ControlPanel/Timer
@onready var countdown_label: Label = $CanvasLayer/CountdownLabel
@onready var p1_buttons: Label = $CanvasLayer/P1Panel/P1Buttons
@onready var p2_buttons: Label = $CanvasLayer/P2Panel/P2Buttons
@onready var p1_feedback: Label = $CanvasLayer/P1Panel/P1Feedback
@onready var p2_feedback: Label = $CanvasLayer/P2Panel/P2Feedback

# Player data
var player1_data
var player2_data

# Minigame settings
@export var duration: float = 60.0  # seconds
@export var countdown_duration: float = 3.0
@export var surface_y: float = 100.0  # Y position of water surface (top)
@export var finish_line_y: float = 50.0  # Y position of finish line (above surface)
@export var drown_threshold_y: float = 500.0  # Y position where player drowns
@export var level_bottom_y: float = 600.0  # Bottom of level (drown zone)

# Level dimensions
@export var level_width: float = 640.0
@export var start_x: float = 200.0

# Game timer
var game_timer: float = 0.0
var countdown_timer: float = 0.0

# Win condition tracking
var p1_finished: bool = false
var p2_finished: bool = false

# MinigameConnection reference for stake handling
var minigame_connection: Node = null

# Challenge stake information
var current_stake: Dictionary = {
	"organ_wagered": "",
	"stake_multiplier": 1.0,
	"player_index": -1
}

signal minigame_ended(winner_id: int)
# Signal for reporting result to MinigameConnection
signal minigame_result(player_index: int, success: bool, winner_id: int)

func _ready() -> void:
	_setup_ui_references()
	_initialize_players()
	_setup_level_visuals()
	game_state = GameState.WAITING
	status_label.text = "Press SPACE to start"
	countdown_label.visible = false

func _setup_ui_references() -> void:
	if control_panel:
		control_panel.self_modulate = Color(1, 1, 1, 0.9)
	
	if countdown_label:
		countdown_label.add_theme_font_size_override("font_size", 72)
		countdown_label.self_modulate = Color(1, 1, 1, 1)
	
	if status_label:
		status_label.text = "PRESS SPACE TO START"
		status_label.self_modulate = Color(1, 1, 1, 1)
		status_label.add_theme_color_override("font_color", Color(0, 1, 0.5, 1))

func _initialize_players() -> void:
	# PlayerData is an autoload singleton - access via get_node to avoid class_name shadowing
	# For 2-player data, we use the same singleton but copy organs
	var pd = get_node("/root/PlayerData")
	player1_data = pd
	player2_data = pd
	
	# Debug logging to validate node and method resolution
	print("[NageLevel] _initialize_players: p1=%s, p2=%s" % [p1, p2])
	print("[NageLevel] player1_data=%s, organs=%s" % [player1_data, player1_data.organs if player1_data else "null"])
	
	if p1 and p1.has_method("set_player_organs"):
		var organs_copy = player1_data.organs.duplicate() if player1_data and player1_data.has("organs") else {}
		print("[NageLevel] Calling p1.set_player_organs with: %s" % organs_copy)
		p1.set_player_organs(organs_copy)
	else:
		print("[NageLevel] WARNING: p1 is null or has no set_player_organs method")
	
	if p2 and p2.has_method("set_player_organs"):
		var organs_copy = player2_data.organs.duplicate() if player2_data and player2_data.has("organs") else {}
		print("[NageLevel] Calling p2.set_player_organs with: %s" % organs_copy)
		p2.set_player_organs(organs_copy)
	else:
		print("[NageLevel] WARNING: p2 is null or has no set_player_organs method")
	
	if p1 and p1.has_method("reset_for_new_game"):
		p1.reset_for_new_game()
	if p2 and p2.has_method("reset_for_new_game"):
		p2.reset_for_new_game()
	
	p1.position = Vector2(100, level_bottom_y - 100)
	p2.position = Vector2(300, level_bottom_y - 100)

func _setup_level_visuals() -> void:
	pass

func _start_countdown() -> void:
	game_state = GameState.COUNTDOWN
	countdown_timer = countdown_duration
	countdown_label.visible = true
	countdown_label.text = "3"
	status_label.text = "Get ready!"
	p1_finished = false
	p2_finished = false

# ============================================
# BUMPER-ONLY INPUT SYSTEM
# P1: Gamepad 0 L1/R1 | P2: Gamepad 1 L1/R1
# ============================================

func is_p1_button_a_pressed() -> bool:
	"""P1 Left Bumper (L1) on gamepad 0"""
	return Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER)

func is_p1_button_b_pressed() -> bool:
	"""P1 Right Bumper (R1) on gamepad 0"""
	return Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER)

func is_p2_button_a_pressed() -> bool:
	"""P2 Left Bumper (L1) on gamepad 1"""
	return Input.is_joy_button_pressed(1, JOY_BUTTON_LEFT_SHOULDER)

func is_p2_button_b_pressed() -> bool:
	"""P2 Right Bumper (R1) on gamepad 1"""
	return Input.is_joy_button_pressed(1, JOY_BUTTON_RIGHT_SHOULDER)

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
		countdown_label.text = "SWIM!"
		_start_game()

func _start_game() -> void:
	game_state = GameState.PLAYING
	game_timer = 0.0
	countdown_label.visible = false
	status_label.text = "SWIM! Reach the surface!"

func _update_gameplay(delta: float) -> void:
	game_timer += delta
	
	var time_left = max(0, duration - game_timer)
	timer_label.text = "Time: %.1f" % time_left
	
	_update_player(p1, player1_data, 1, delta)
	_update_player(p2, player2_data, 2, delta)
	
	_update_button_feedback()
	_check_win_conditions()
	
	if game_timer >= duration:
		_end_game(_determine_winner_by_position())

func _update_player(player: Node2D, player_data: PlayerData, player_id: int, delta: float) -> void:
	if not player.has_method("is_player_drowned"):
		return
	
	if player_data and player_data.has_method("process_lungs_challenge"):
		player_data.process_lungs_challenge(delta)
	
	var is_underwater = player.position.y > surface_y
	if player.has_method("set_surface_status"):
		player.set_surface_status(not is_underwater)
	
	player.position.x = clamp(player.position.x, 20, level_width - 20)
	
	if player.position.y >= level_bottom_y:
		if player.has_method("set_drowned"):
			player.set_drowned(true)
	
	if player.has_method("is_at_surface") and player.has_method("can_catch_air"):
		if player.is_at_surface() and player.can_catch_air():
			_handle_catch_air_input(player, player_id)
	
	if player.position.y <= finish_line_y:
		if player_id == 1:
			p1_finished = true
		else:
			p2_finished = true

func _handle_catch_air_input(player: Node2D, player_id: int) -> void:
	var catch_button = false
	
	if player_id == 1:
		catch_button = is_p1_button_a_pressed() or is_p1_button_b_pressed()
	else:
		catch_button = is_p2_button_a_pressed() or is_p2_button_b_pressed()
	
	if catch_button and player.has_method("catch_air"):
		player.catch_air()

func _update_button_feedback() -> void:
	var p1_a = is_p1_button_a_pressed()
	var p1_b = is_p1_button_b_pressed()
	
	if p1_a:
		p1_buttons.text = "[L1*]  [R1]"
	elif p1_b:
		p1_buttons.text = "[L1]   [R1*]"
	else:
		p1_buttons.text = "[L1]   [R1]"
	
	var p2_a = is_p2_button_a_pressed()
	var p2_b = is_p2_button_b_pressed()
	
	if p2_a:
		p2_buttons.text = "[L1*]  [R1]"
	elif p2_b:
		p2_buttons.text = "[L1]   [R1*]"
	else:
		p2_buttons.text = "[L1]   [R1]"
	
	if p1.has_method("get_alternation_speed"):
		var p1_speed = p1.get_alternation_speed()
		if p1_speed > 0.5:
			p1_feedback.text = "Rhythm: %.1f" % p1_speed
		else:
			p1_feedback.text = "Alternate L1/R1"
	
	if p2.has_method("get_alternation_speed"):
		var p2_speed = p2.get_alternation_speed()
		if p2_speed > 0.5:
			p2_feedback.text = "Rhythm: %.1f" % p2_speed
		else:
			p2_feedback.text = "Alternate L1/R1"

func _check_win_conditions() -> void:
	if p1_finished and not p2_finished:
		_end_game(1)
	elif p2_finished and not p1_finished:
		_end_game(2)
	elif p1_finished and p2_finished:
		_end_game(0)
	
	if p1.has_method("is_player_drowned") and p2.has_method("is_player_drowned"):
		if p1.is_player_drowned() and not p2.is_player_drowned():
			_end_game(2)
		elif p2.is_player_drowned() and not p1.is_player_drowned():
			_end_game(1)
		elif p1.is_player_drowned() and p2.is_player_drowned():
			_end_game(0)

func _determine_winner_by_position() -> int:
	if p1.position.y < p2.position.y:
		return 1
	elif p2.position.y < p1.position.y:
		return 2
	else:
		return 0

func _end_game(winner_id: int) -> void:
	game_state = GameState.FINISHED
	
	var result_text = ""
	if winner_id > 0:
		result_text = "Player %d Wins!" % winner_id
	elif winner_id == 0:
		result_text = "It's a Tie!"
	else:
		result_text = "Time's Up!"
	
	status_label.text = result_text
	countdown_label.text = result_text
	countdown_label.visible = true
	
	# Report result to MinigameConnection
	emit_signal("minigame_result", current_stake.get("player_index", -1), winner_id > 0, winner_id)
	
	await get_tree().create_timer(3.0).timeout
	minigame_ended.emit(winner_id)

## Set stake information for this minigame session
func set_stake(player_index: int, organ_wagered: String, multiplier: float = 1.0) -> void:
	current_stake = {
		"player_index": player_index,
		"organ_wagered": organ_wagered,
		"stake_multiplier": multiplier
	}

## Get current stake info
func get_stake() -> Dictionary:
	return current_stake.duplicate(true)

## Start game with stake information
func start_game_with_stake(player_index: int, organ_wagered: String, multiplier: float = 1.0) -> void:
	set_stake(player_index, organ_wagered, multiplier)
	_start_countdown()

func force_start() -> void:
	_start_countdown()
