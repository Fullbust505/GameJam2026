extends Node2D

## Cuisine/Cutting minigame level controller.
## Handles knife-based minigame for kidney/liver/pancreas challenges.

# Minigame state
enum GameState { WAITING, COUNTDOWN, PLAYING, FINISHED }
var game_state: GameState = GameState.WAITING

# Players (using same P1/P2 scenes as swimming)
@onready var p1: Node2D = $P1
@onready var p2: Node2D = $P2

# UI References
@onready var status_label: Label = $CanvasLayer/ControlPanel/Status if has_node("CanvasLayer/ControlPanel/Status") else null
@onready var timer_label: Label = $CanvasLayer/ControlPanel/Timer if has_node("CanvasLayer/ControlPanel/Timer") else null
@onready var countdown_label: Label = $CanvasLayer/CountdownLabel if has_node("CanvasLayer/CountdownLabel") else null

# Game timer
var game_timer: float = 0.0
var countdown_timer: float = 0.0

# Win condition tracking
var p1_score: int = 0
var p2_score: int = 0

# Minigame settings
@export var duration: float = 60.0
@export var countdown_duration: float = 3.0

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

# Signal for result reporting (1-based winner like cuisine uses)
signal minigame_ended(winner_id: int)
signal minigame_result(player_index: int, success: bool, winner_id: int)

func _ready() -> void:
	# Get animations helper
	_animations = get_node_or_null("/root/Animations")
	game_state = GameState.WAITING
	if countdown_label:
		countdown_label.visible = false
	if status_label:
		status_label.text = "Press SPACE to start"

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
	if countdown_label:
		countdown_label.visible = true
		if seconds_left > 0:
			countdown_label.text = str(seconds_left)
		else:
			countdown_label.text = "CUT!"
			_start_game()

func _start_countdown() -> void:
	game_state = GameState.COUNTDOWN
	countdown_timer = countdown_duration
	p1_score = 0
	p2_score = 0

func _start_game() -> void:
	game_state = GameState.PLAYING
	game_timer = 0.0
	if countdown_label:
		countdown_label.visible = false
	if status_label:
		status_label.text = "CUT!"

func _update_gameplay(delta: float) -> void:
	game_timer += delta
	
	if timer_label:
		var time_left = max(0, duration - game_timer)
		timer_label.text = "Time: %.1f" % time_left
		
		# Timer urgency animation when low
		if time_left <= 10.0 and _animations:
			_animations.timer_urgent(timer_label)
	
	# Track cutting scores (simplified - actual implementation would track cuts)
	_update_cutting_scores()
	
	if game_timer >= duration:
		_end_game(_determine_winner())

func _update_cutting_scores() -> void:
	# Simplified scoring - actual implementation would detect cuts
	# P1 uses keyboard arrows or gamepad 0
	if Input.is_action_pressed("ui_left") or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER):
		p1_score += 1
	if Input.is_action_pressed("ui_right") or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER):
		p1_score += 1
	
	# P2 uses gamepad 1
	if Input.is_joy_button_pressed(1, JOY_BUTTON_LEFT_SHOULDER):
		p2_score += 1
	if Input.is_joy_button_pressed(1, JOY_BUTTON_RIGHT_SHOULDER):
		p2_score += 1

func _determine_winner() -> int:
	# Return 0-based: 0 = tie, 1 = player 1 (p1 index 0), 2 = player 2 (p2 index 1)
	if p1_score > p2_score:
		return 1  # P1 wins
	elif p2_score > p1_score:
		return 2  # P2 wins
	else:
		return 0  # Tie

func _end_game(winner_id: int) -> void:
	game_state = GameState.FINISHED
	
	var result_text = ""
	if winner_id > 0:
		result_text = "Player %d Wins!" % winner_id
	elif winner_id == 0:
		result_text = "It's a Tie!"
	
	if status_label:
		status_label.text = result_text
	if countdown_label:
		countdown_label.text = result_text
		countdown_label.visible = true
	
	# Apply result animation
	if _animations:
		if winner_id > 0:
			_animations.win_text(countdown_label, 2.0)
		else:
			_animations.lose_text(countdown_label, 2.0)
	
	# Report result to MinigameConnection
	emit_signal("minigame_result", current_stake.get("player_index", -1), winner_id > 0, winner_id)
	
	await get_tree().create_timer(3.0).timeout
	minigame_ended.emit(winner_id)

func force_start() -> void:
	_start_countdown()

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

## Add score to player (called by cut detection)
func add_score(player_id: int, points: int) -> void:
	if player_id == 1:
		p1_score += points
	elif player_id == 2:
		p2_score += points
