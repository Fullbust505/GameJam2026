extends Node

@export var target_depth := 800.0
@export var max_oxygen := 100.0
@export var oxygen_decay_rate := 8.0
@export var oxygen_recover_rate := 25.0
@export var swim_speed := 300.0

@onready var p1 = $P1
@onready var p2 = $P2
@onready var anchor = $Anchor
@onready var timer = $Timer
@onready var duration_timer = $DurationTimer

var p1_oxygen := max_oxygen
var p2_oxygen := max_oxygen
var p1_depth := 0.0
var p2_depth := 0.0
var game_started := false
var game_ended := false

var p1_at_surface := true
var p2_at_surface := true

@onready var p1_readiness = $"../../../../p1readiness"
@onready var p2_readiness = $"../../../../p2readiness"
@onready var tuto_label = $"../../../../tuto/tuto_desc"
@onready var label = $"../../../../Label"

var json_path = "res://game_state.json"
var gamestate : Dictionary = {}

func _ready() -> void:
	open_json(json_path)
	p1_readiness.animation = "waiting"
	p2_readiness.animation = "waiting"
	tuto_label.text = "Hold the button to swim DOWN.\nRelease to go UP.\nReach the anchor first!\nDon't run out of oxygen!"
	timer.wait_time = 3
	timer.start()
	duration_timer.wait_time = 45.0

func _process(delta: float) -> void:
	if not game_started:
		return
	if game_ended:
		return

	update_oxygen(delta)
	update_depths(delta)
	check_win_condition()

	var s_dur = duration_timer.time_left
	label.text = '%02d' % [s_dur] if s_dur > 0 else "00"

func update_oxygen(delta: float) -> void:
	# P1 oxygen
	if p1_at_surface:
		p1_oxygen = min(p1_oxygen + oxygen_recover_rate * delta, max_oxygen)
	else:
		p1_oxygen -= oxygen_decay_rate * delta

	# P2 oxygen
	if p2_at_surface:
		p2_oxygen = min(p2_oxygen + oxygen_recover_rate * delta, max_oxygen)
	else:
		p2_oxygen -= oxygen_decay_rate * delta

	p1_oxygen = clamp(p1_oxygen, 0, max_oxygen)
	p2_oxygen = clamp(p2_oxygen, 0, max_oxygen)

func update_depths(delta: float) -> void:
	# P1 depth based on input (holding button = going down)
	var p1_input_down = Input.is_joy_button_pressed(0, JOY_BUTTON_A) or Input.is_action_pressed("game_main_button")
	var p2_input_down = Input.is_joy_button_pressed(1, JOY_BUTTON_A) or Input.is_action_pressed("game_main_button_2")

	# Determine if at surface (shallow depth means at surface)
	p1_at_surface = p1_depth < 50
	p2_at_surface = p2_depth < 50

	if p1_input_down and p1_oxygen > 0:
		p1_depth += swim_speed * delta
	else:
		p1_depth -= swim_speed * 0.5 * delta

	if p2_input_down and p2_oxygen > 0:
		p2_depth += swim_speed * delta
	else:
		p2_depth -= swim_speed * 0.5 * delta

	# Clamp depth
	p1_depth = clamp(p1_depth, 0, target_depth * 1.5)
	p2_depth = clamp(p2_depth, 0, target_depth * 1.5)

	# Update player positions
	p1.position.y = p1_depth
	p2.position.y = p2_depth

	# Update anchor position
	anchor.position.y = target_depth

func check_win_condition() -> void:
	var p1_wins = false
	var p2_wins = false

	# Check if anyone reached target depth
	if p1_depth >= target_depth:
		p1_wins = true
	if p2_depth >= target_depth:
		p2_wins = true

	# Check oxygen depletion (lose if oxygen runs out at depth)
	if p1_oxygen <= 0 and p1_depth > 100:
		p1_wins = false  # P1 drowned basically
	if p2_oxygen <= 0 and p2_depth > 100:
		p2_wins = false

	# Determine winner
	if p1_wins and not p2_wins:
		end_game("0")
	elif p2_wins and not p1_wins:
		end_game("1")
	elif p1_wins and p2_wins:
		# Both reached - whoever is deeper wins
		if p1_depth >= p2_depth:
			end_game("0")
		else:
			end_game("1")

func end_game(winner: String) -> void:
	if game_ended:
		return
	game_ended = true
	game_started = false

	gamestate["last_winner"] = winner
	gamestate["players"]["p" + winner]["score"] += 1
	gamestate["players"]["p" + winner]["money"] += 300
	write_json(gamestate)

	duration_timer.start()

func _on_timer_timeout() -> void:
	p1_readiness.visible = false
	p2_readiness.visible = false
	game_started = true
	duration_timer.start()

func _on_duration_timer_timeout() -> void:
	# Time's up - determine winner by depth
	var winner = "0" if p1_depth >= p2_depth else "1"
	end_game(winner)

func open_json(path):
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = file.get_as_text()
		var json_object = JSON.new()
		json_object.parse(json)
		gamestate = json_object.data
		file.close()
	else:
		# Default gamestate
		gamestate = {
			"players": {
				"p1": {"score": 0, "money": 0},
				"p2": {"score": 0, "money": 0}
			},
			"last_winner": "0"
		}

func write_json(state):
	var file = FileAccess.open("res://game_state.json", FileAccess.WRITE)
	var json_text = JSON.stringify(state, '\t')
	file.store_string(json_text)
	file.close()
