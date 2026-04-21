extends Node2D

# Drinking Level Controller - Manages the drinking/alcohol minigame
# Wii Party-style drinking competition between two players
# ONLY gamepad input - A button to drink

signal game_ended(winner_id: String)
signal minigame_result(player_index: int, success: bool, winner_id: String)
signal minigame_ended(winner_id: String)
signal countdown_tick(tick: int)
signal coma_warning(player_id: String, intensity: float)

# Game states
enum GameState {
	PREGAME,
	WAITING,
	COUNTDOWN,
	PLAYING,
	FINISHED
}

# Game configuration
const GAME_DURATION: float = 60.0
const COUNTDOWN_DURATION: float = 3.0

# Node references
@onready var p1: Node2D = $P1
@onready var p2: Node2D = $P2
@onready var hud: CanvasLayer = $HUD
@onready var background: ColorRect = $Background
@onready var countdown_label: Label = $CountdownLabel

# Pre-game popup references
@onready var pregame_panel: Panel = $PregamePanel
@onready var pregame_title: Label = $PregamePanel/Title
@onready var pregame_goal: Label = $PregamePanel/Goal
@onready var pregame_p1_controls: Label = $PregamePanel/P1Controls
@onready var pregame_p2_controls: Label = $PregamePanel/P2Controls
@onready var pregame_prompt: Label = $PregamePanel/Prompt
var pregame_timer: float = 5.0

# Game state
var game_state: GameState = GameState.PREGAME
var game_timer: float = 0.0
var countdown_timer: float = 0.0
var countdown_value: int = 3

# Track awake time for coma tiebreaker
var p1_awake_time: float = 0.0
var p2_awake_time: float = 0.0

# Input settings reference
var input_settings: Node = null

# MinigameConnection reference for stake handling
var minigame_connection: Node = null

# Challenge stake information
var current_stake: Dictionary = {
	"organ_wagered": "",
	"stake_multiplier": 1.0,
	"player_index": -1
}

# Animation helper
var _animations: Node = null

func _ready() -> void:
	# Get input settings
	input_settings = get_node_or_null("/root/InputSettings")
	_animations = get_node_or_null("/root/Animations")
	
	# Setup HUD if available
	_setup_hud()
	
	# Connect player signals
	_connect_player_signals()
	
	# Show pre-game popup first
	_show_pregame_popup()

func _show_pregame_popup() -> void:
	# Configure pre-game popup content
	if pregame_panel:
		pregame_panel.visible = true
	
	if pregame_title:
		pregame_title.text = "DRINKING CONTEST"
	
	if pregame_goal:
		pregame_goal.text = "Drink the most without falling into a coma!\nYour liver affects alcohol tolerance."
	
	if pregame_p1_controls:
		pregame_p1_controls.text = "[A Button = Drink (mash fast!)]"
	
	if pregame_p2_controls:
		pregame_p2_controls.text = "[A Button = Drink (mash fast!)]"
	
	if pregame_prompt:
		pregame_prompt.text = "Press A to Start"
	
	pregame_timer = 5.0

func _setup_hud() -> void:
	if hud and hud.has_node("P1AlcoholBar"):
		hud.get_node("P1AlcoholBar").max_value = 100.0
		hud.get_node("P1AlcoholBar").value = 0.0
	if hud and hud.has_node("P2AlcoholBar"):
		hud.get_node("P2AlcoholBar").max_value = 100.0
		hud.get_node("P2AlcoholBar").value = 0.0
	if hud and hud.has_node("TimerLabel"):
		hud.get_node("TimerLabel").text = "60"
	if hud and hud.has_node("P1Status"):
		hud.get_node("P1Status").text = ""
	if hud and hud.has_node("P2Status"):
		hud.get_node("P2Status").text = ""

func _connect_player_signals() -> void:
	# Connect alcohol changed signals
	if p1 and p1.has_signal("alcohol_changed"):
		p1.alcohol_changed.connect(_on_p1_alcohol_changed)
	if p2 and p2.has_signal("alcohol_changed"):
		p2.alcohol_changed.connect(_on_p2_alcohol_changed)
	
	# Connect coma signals
	if p1 and p1.has_signal("coma_started"):
		p1.coma_started.connect(_on_p1_coma_started)
		p1.coma_ended.connect(_on_p1_coma_ended)
	if p2 and p2.has_signal("coma_started"):
		p2.coma_started.connect(_on_p2_coma_started)
		p2.coma_ended.connect(_on_p2_coma_ended)

func _process(delta: float) -> void:
	match game_state:
		GameState.PREGAME:
			_update_pregame(delta)
		GameState.COUNTDOWN:
			_process_countdown(delta)
		GameState.PLAYING:
			_process_playing(delta)
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
	
	_start_countdown()

func _process_countdown(delta: float) -> void:
	countdown_timer += delta
	var new_value = COUNTDOWN_DURATION - countdown_timer
	
	if new_value != countdown_value and new_value > 0:
		countdown_value = int(new_value)
		countdown_label.text = str(countdown_value)
		countdown_tick.emit(countdown_value)
		if _animations:
			_animations.countdown_effect()
	
	if countdown_timer >= COUNTDOWN_DURATION:
		_start_game()

func _process_playing(delta: float) -> void:
	# Handle input - GAMEPAD ONLY
	_handle_input()
	
	# Update timer
	game_timer += delta
	_update_timer_display()
	
	# Track awake time for tiebreaker
	if p1 and p1.is_comatose():
		pass
	elif p1:
		p1_awake_time += delta
	if p2 and p2.is_comatose():
		pass
	elif p2:
		p2_awake_time += delta
	
	# Check coma warnings
	_check_coma_warnings()
	
	# Check game end
	if game_timer >= GAME_DURATION:
		_end_game()

func _handle_input() -> void:
	# Player 1 drinking input - gamepad 0 A button only
	var p1_drink_pressed = Input.is_joy_button_pressed(0, JOY_BUTTON_A)
	if p1_drink_pressed:
		if p1 and p1.has_method("drink"):
			p1.drink()
	
	# Player 2 drinking input - gamepad 1 A button only
	var p2_drink_pressed = Input.is_joy_button_pressed(1, JOY_BUTTON_A)
	if p2_drink_pressed:
		if p2 and p2.has_method("drink"):
			p2.drink()

func _check_coma_warnings() -> void:
	if p1 and p1.get_alcohol_level() > 60:
		var intensity = (p1.get_alcohol_level() - 60) / 40.0
		coma_warning.emit("p1", intensity)
	if p2 and p2.get_alcohol_level() > 60:
		var intensity = (p2.get_alcohol_level() - 60) / 40.0
		coma_warning.emit("p2", intensity)

func _update_timer_display() -> void:
	if hud and hud.has_node("TimerLabel"):
		var remaining = max(0, GAME_DURATION - game_timer)
		hud.get_node("TimerLabel").text = str(int(remaining))

func _start_countdown() -> void:
	game_state = GameState.COUNTDOWN
	countdown_timer = 0.0
	countdown_value = 3
	countdown_label.text = "3"
	countdown_label.visible = true
	
	# Reset players
	if p1 and p1.has_method("reset"):
		p1.reset()
	if p2 and p2.has_method("reset"):
		p2.reset()
	
	p1_awake_time = 0.0
	p2_awake_time = 0.0

func _start_game() -> void:
	game_state = GameState.PLAYING
	countdown_label.visible = false
	game_timer = 0.0
	
	if _animations:
		_animations.challenge_start_effect()
	
	_update_hud()

func _end_game() -> void:
	game_state = GameState.FINISHED
	
	# Determine winner
	var winner_id = _determine_winner()
	
	# Emit signals
	game_ended.emit(winner_id)
	emit_signal("minigame_ended", winner_id)
	emit_signal("minigame_result", current_stake.get("player_index", -1), winner_id != "tie", winner_id)
	
	# Apply result animation
	if _animations:
		if winner_id == "tie":
			_animations.lose_text(null, 1.5)
		else:
			_animations.win_text(null, 1.5)

func _determine_winner() -> String:
	var p1_alcohol = 0.0
	var p2_alcohol = 0.0
	
	if p1 and p1.has_method("get_alcohol_level"):
		p1_alcohol = p1.get_alcohol_level()
	if p2 and p2.has_method("get_alcohol_level"):
		p2_alcohol = p2.get_alcohol_level()
	
	# Both in coma - compare awake time
	if p1.is_comatose() and p2.is_comatose():
		if p1_awake_time > p2_awake_time:
			return "p1"
		elif p2_awake_time > p1_awake_time:
			return "p2"
		else:
			return "tie"
	
	# One in coma - other wins
	if p1.is_comatose():
		return "p2"
	if p2.is_comatose():
		return "p1"
	
	# Normal comparison
	if p1_alcohol > p2_alcohol:
		return "p1"
	elif p2_alcohol > p1_alcohol:
		return "p2"
	else:
		return "tie"

func _update_hud() -> void:
	if hud:
		if p1 and hud.has_node("P1AlcoholBar"):
			hud.get_node("P1AlcoholBar").value = p1.get_alcohol_level()
		if p2 and hud.has_node("P2AlcoholBar"):
			hud.get_node("P2AlcoholBar").value = p2.get_alcohol_level()

func _on_p1_alcohol_changed(player_id: String, level: float) -> void:
	if hud and hud.has_node("P1AlcoholBar"):
		hud.get_node("P1AlcoholBar").value = level

func _on_p2_alcohol_changed(player_id: String, level: float) -> void:
	if hud and hud.has_node("P2AlcoholBar"):
		hud.get_node("P2AlcoholBar").value = level

func _on_p1_coma_started(player_id: String) -> void:
	if hud and hud.has_node("P1Status"):
		hud.get_node("P1Status").text = "COMA!"
	if _animations:
		_animations.warning_effect()

func _on_p1_coma_ended(player_id: String) -> void:
	if hud and hud.has_node("P1Status"):
		hud.get_node("P1Status").text = ""

func _on_p2_coma_started(player_id: String) -> void:
	if hud and hud.has_node("P2Status"):
		hud.get_node("P2Status").text = "COMA!"
	if _animations:
		_animations.warning_effect()

func _on_p2_coma_ended(player_id: String) -> void:
	if hud and hud.has_node("P2Status"):
		hud.get_node("P2Status").text = ""

## Start game with stake information
func start_game_with_stake(player_index: int, organ_wagered: String, multiplier: float = 1.0) -> void:
	set_stake(player_index, organ_wagered, multiplier)
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

func is_game_active() -> bool:
	return game_state == GameState.PLAYING

func get_game_state() -> GameState:
	return game_state

func get_time_remaining() -> float:
	return max(0, GAME_DURATION - game_timer)