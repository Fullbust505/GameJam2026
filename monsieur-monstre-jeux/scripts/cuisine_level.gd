extends Node2D

## Cuisine/Cutting minigame level controller.
## Handles knife-based minigame for kidney/liver/pancreas challenges.
## ONLY gamepad input - D-Pad for position, A button to cut

# Minigame state
enum GameState { PREGAME, WAITING, COUNTDOWN, PLAYING, FINISHED }
var game_state: GameState = GameState.PREGAME

# Players (using same P1/P2 scenes as swimming)
@onready var p1: Node2D = $P1
@onready var p2: Node2D = $P2

# UI References
@onready var status_label: Label = $CanvasLayer/ControlPanel/Status if has_node("CanvasLayer/ControlPanel/Status") else null
@onready var timer_label: Label = $CanvasLayer/ControlPanel/Timer if has_node("CanvasLayer/ControlPanel/Timer") else null
@onready var countdown_label: Label = $CanvasLayer/CountdownLabel if has_node("CanvasLayer/CountdownLabel") else null

# Pre-game popup references
@onready var pregame_panel: Panel = $CanvasLayer/PregamePanel if has_node("CanvasLayer/PregamePanel") else null
@onready var pregame_title: Label = $CanvasLayer/PregamePanel/Title if has_node("CanvasLayer/PregamePanel/Title") else null
@onready var pregame_goal: Label = $CanvasLayer/PregamePanel/Goal if has_node("CanvasLayer/PregamePanel/Goal") else null
@onready var pregame_p1_controls: Label = $CanvasLayer/PregamePanel/P1Controls if has_node("CanvasLayer/PregamePanel/P1Controls") else null
@onready var pregame_p2_controls: Label = $CanvasLayer/PregamePanel/P2Controls if has_node("CanvasLayer/PregamePanel/P2Controls") else null
@onready var pregame_prompt: Label = $CanvasLayer/PregamePanel/Prompt if has_node("CanvasLayer/PregamePanel/Prompt") else null
var pregame_timer: float = 5.0

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
	game_state = GameState.PREGAME
	if countdown_label:
		countdown_label.visible = false
	if status_label:
		status_label.text = ""
	
	_show_pregame_popup()

func _show_pregame_popup() -> void:
	# Configure pre-game popup content
	if pregame_panel:
		pregame_panel.visible = true
	
	if pregame_title:
		pregame_title.text = "CUTTING CHALLENGE"
	
	if pregame_goal:
		pregame_goal.text = "Cut the ingredient!\nMatch the displayed pattern."
	
	if pregame_p1_controls:
		pregame_p1_controls.text = "[D-Pad = Position] [A Button = Cut]"
	
	if pregame_p2_controls:
		pregame_p2_controls.text = "[D-Pad = Position] [A Button = Cut]"
	
	if pregame_prompt:
		pregame_prompt.text = "Press A to Start"
	
	pregame_timer = 5.0

func _process(delta: float) -> void:
	match game_state:
		GameState.PREGAME:
			_update_pregame(delta)
		GameState.WAITING:
			_update_waiting_state()
		GameState.COUNTDOWN:
			_update_countdown(delta)
		GameState.PLAYING:
			_update_gameplay(delta)
		GameState.FINISHED:
			pass

func _update_pregame(delta: float) -> void:
	# Check for A button press on either gamepad to dismiss
	var p1_a_pressed = Input.is_joy_button_pressed(0, JOY_BUTTON_A)
	var p2_a_pressed = Input.is_joy_button_pressed(1, JOY_BUTTON_A)
	
	if p1_a_pressed or p2_a_pressed:
		_dismiss_pregame_popup()
		return
	
	# Auto-dismiss timer
	pregame_timer -= delta
	if pregame_timer <= 0:
		_dismiss_pregame_popup()
	
	# Blink the prompt
	if pregame_prompt:
		var blink = sin(pregame_timer * 4.0) > 0
		pregame_prompt.self_modulate = Color(1, 1, 0.5, 1.0 if blink else 0.5)

func _dismiss_pregame_popup() -> void:
	if pregame_panel:
		pregame_panel.visible = false
	
	game_state = GameState.WAITING
	if status_label:
		status_label.text = "Press A to Start"

func _update_waiting_state() -> void:
	# Use gamepad A button to start (either player)
	var p1_a_pressed = Input.is_joy_button_pressed(0, JOY_BUTTON_A)
	var p2_a_pressed = Input.is_joy_button_pressed(1, JOY_BUTTON_A)
	
	if p1_a_pressed or p2_a_pressed:
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
			if _animations:
				_animations.challenge_start_effect()
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
	
	# Track cutting scores - GAMEPAD ONLY
	_update_cutting_scores()
	
	if game_timer >= duration:
		_end_game(_determine_winner())

func _update_cutting_scores() -> void:
	# P1 uses D-pad up/down on gamepad 0 (move) and A button to cut
	var p1_dpad_up = Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP)
	var p1_dpad_down = Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN)
	var p1_a_pressed = Input.is_joy_button_pressed(0, JOY_BUTTON_A)
	
	if p1_dpad_up:
		p1_score += 1
	if p1_dpad_down:
		p1_score += 1
	# A button for cutting action
	if p1_a_pressed:
		p1_score += 2
	
	# P2 uses D-pad up/down on gamepad 1 and A button to cut
	var p2_dpad_up = Input.is_joy_button_pressed(1, JOY_BUTTON_DPAD_UP)
	var p2_dpad_down = Input.is_joy_button_pressed(1, JOY_BUTTON_DPAD_DOWN)
	var p2_a_pressed = Input.is_joy_button_pressed(1, JOY_BUTTON_A)
	
	if p2_dpad_up:
		p2_score += 1
	if p2_dpad_down:
		p2_score += 1
	if p2_a_pressed:
		p2_score += 2

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
	_show_pregame_popup()

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
	_show_pregame_popup()

## Add score to player (called by cut detection)
func add_score(player_id: int, points: int) -> void:
	if player_id == 1:
		p1_score += points
	elif player_id == 2:
		p2_score += points