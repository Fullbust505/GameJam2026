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
@onready var fish_container = $FishContainer
@onready var camera = $Camera2D
@onready var oxygen_p1 = $OxygenP1
@onready var oxygen_p2 = $OxygenP2
var tutorial_scene: PackedScene
var tutorial_instance: Node = null

var p1_oxygen := max_oxygen
var p2_oxygen := max_oxygen
var p1_depth := 0.0
var p2_depth := 0.0
var game_started := false
var game_ended := false

# Tutorial/Ready system
enum GameState { TUTORIAL, READY_CHECK, PLAYING, ENDED }
var current_state := GameState.TUTORIAL
var p1_ready := false
var p2_ready := false

var p1_at_surface := true
var p2_at_surface := true

# Organ states for both players
var p1_organs := {
	"lungs": true, "heart": true, "arms": true, "legs": true,
	"liver": true, "pancreas": true, "mouth": true, "eyes": true
}
var p2_organs := {
	"lungs": true, "heart": true, "arms": true, "legs": true,
	"liver": true, "pancreas": true, "mouth": true, "eyes": true
}

# Liver toxin levels
var p1_toxin_level := 0.0
var p2_toxin_level := 0.0

# Global organ effects singleton
var organ_global_effects: Node = null

# Input type for swimming (trigger mashing vs button hold)
enum SwimInputType { TRIGGERS, LEGACY }
var p1_swim_input := SwimInputType.TRIGGERS
var p2_swim_input := SwimInputType.TRIGGERS

# Trigger mash tracking for P1
var p1_lz_pressed := false
var p1_rz_pressed := false
var p1_last_lz := false
var p1_last_rz := false

# Trigger mash tracking for P2
var p2_lz_pressed := false
var p2_rz_pressed := false
var p2_last_lz := false
var p2_last_rz := false

# Tutorial/Ready system

# Fish enemies
var fish_scene: PackedScene
var fishes: Array = []
var fish_spawn_timer := 0.0
var fish_spawn_interval := 5.0
var max_fish := 5

var json_path = "res://game_state.json"
var gamestate : Dictionary = {}

func _ready() -> void:
	open_json(json_path)

	# Load organ states from gamestate
	_load_organ_states()

	# Load fish scene
	fish_scene = preload("res://scenes/fish_enemy.tscn")

	# Setup oxygen bars
	if oxygen_p1:
		oxygen_p1.max_value = max_oxygen
		oxygen_p1.value = max_oxygen
	if oxygen_p2:
		oxygen_p2.max_value = max_oxygen
		oxygen_p2.value = max_oxygen

	# Center camera at start
	if camera:
		camera.position = Vector2(540, 400)

	# Load tutorial scene
	tutorial_scene = preload("res://scenes/apnee_tutorial.tscn")

	# Start with tutorial
	_show_tutorial()

var tutorial_p1_label: Label
var tutorial_p2_label: Label

func _show_tutorial() -> void:
	tutorial_instance = tutorial_scene.instantiate()
	add_child(tutorial_instance)
	tutorial_p1_label = tutorial_instance.get_node_or_null("P1Prompt")
	tutorial_p2_label = tutorial_instance.get_node_or_null("P2Prompt")

func _remove_tutorial() -> void:
	if tutorial_instance:
		tutorial_instance.queue_free()
		tutorial_instance = null

func _freeze_player_physics() -> void:
	# Get RigidBody2D children and freeze them
	var p1_rb = p1.get_node_or_null("RigidBody2D")
	var p2_rb = p2.get_node_or_null("RigidBody2D")
	if p1_rb:
		p1_rb.freeze = true
	if p2_rb:
		p2_rb.freeze = true

func _update_tutorial_ui() -> void:
	pass

func _process(delta: float) -> void:
	match current_state:
		GameState.TUTORIAL:
			_process_tutorial(delta)
		GameState.READY_CHECK:
			_process_ready_check(delta)
		GameState.PLAYING:
			_process_gameplay(delta)
		GameState.ENDED:
			pass

func _process_tutorial(_delta: float) -> void:
	# Wait for both players to press A to start
	var p1_pressed = Input.is_joy_button_pressed(0, JOY_BUTTON_A) or Input.is_action_just_pressed("game_main_button")
	var p2_pressed = Input.is_joy_button_pressed(1, JOY_BUTTON_A) or Input.is_action_just_pressed("game_main_button_2")

	if p1_pressed and not p1_ready:
		p1_ready = true
		if tutorial_p1_label:
			tutorial_p1_label.text = "P1: READY!"
			tutorial_p1_label.modulate = Color(0, 1, 0)

	if p2_pressed and not p2_ready:
		p2_ready = true
		if tutorial_p2_label:
			tutorial_p2_label.text = "P2: READY!"
			tutorial_p2_label.modulate = Color(0, 1, 0)

	if p1_ready and p2_ready:
		_remove_tutorial()
		_start_game()

func _process_ready_check(_delta: float) -> void:
	pass

func _start_game() -> void:
	current_state = GameState.PLAYING
	game_started = true

	# Get global effects singleton
	organ_global_effects = get_node_or_null("/root/OrganGlobalEffects")

	# Start duration timer
	duration_timer.wait_time = 45.0
	duration_timer.start()

func _process_gameplay(delta: float) -> void:
	if game_ended:
		return

	update_organ_effects(delta)
	update_oxygen(delta)
	update_depths(delta)
	update_fish(delta)
	update_camera(delta)
	update_oxygen_ui()
	check_win_condition()
	check_fish_collisions()

func update_organ_effects(delta: float) -> void:
	var p1_input = _check_any_input(0)
	var p2_input = _check_any_input(1)

	if not p1_organs["liver"]:
		if p1_input:
			p1_toxin_level += 3.0 * delta
		else:
			p1_toxin_level -= 5.0 * delta
		p1_toxin_level = clampf(p1_toxin_level, 0.0, 100.0)

	if not p2_organs["liver"]:
		if p2_input:
			p2_toxin_level += 3.0 * delta
		else:
			p2_toxin_level -= 5.0 * delta
		p2_toxin_level = clampf(p2_toxin_level, 0.0, 100.0)

func _check_any_input(player_idx: int) -> bool:
	for i in range(16):
		if Input.is_joy_button_pressed(player_idx, i):
			return true
	if abs(Input.get_joy_axis(player_idx, JOY_AXIS_LEFT_X)) > 0.2:
		return true
	if abs(Input.get_joy_axis(player_idx, JOY_AXIS_LEFT_Y)) > 0.2:
		return true
	return false

func _is_trigger_mashing(player_idx: int, is_p1: bool) -> bool:
	var trigger_l = Input.get_joy_axis(player_idx, JOY_AXIS_TRIGGER_LEFT)
	var trigger_r = Input.get_joy_axis(player_idx, JOY_AXIS_TRIGGER_RIGHT)

	var lz_pressed = trigger_l > 0.5
	var rz_pressed = trigger_r > 0.5

	if is_p1:
		var just_pressed_lz = lz_pressed and not p1_last_lz
		var just_pressed_rz = rz_pressed and not p1_last_rz
		p1_last_lz = lz_pressed
		p1_last_rz = rz_pressed
		return just_pressed_lz or just_pressed_rz
	else:
		var just_pressed_lz = lz_pressed and not p2_last_lz
		var just_pressed_rz = rz_pressed and not p2_last_rz
		p2_last_lz = lz_pressed
		p2_last_rz = rz_pressed
		return just_pressed_lz or just_pressed_rz

func _check_swim_input(player_idx: int, is_p1: bool) -> bool:
	var has_legs: bool
	var input_type: SwimInputType
	if is_p1:
		has_legs = p1_organs["legs"]
		input_type = p1_swim_input
	else:
		has_legs = p2_organs["legs"]
		input_type = p2_swim_input

	if input_type == SwimInputType.TRIGGERS:
		if has_legs:
			return _is_trigger_mashing(player_idx, is_p1)
		else:
			var trigger_l = Input.get_joy_axis(player_idx, JOY_AXIS_TRIGGER_LEFT)
			var trigger_r = Input.get_joy_axis(player_idx, JOY_AXIS_TRIGGER_RIGHT)
			var just_pressed_l: bool
			var just_pressed_r: bool
			if is_p1:
				just_pressed_l = trigger_l > 0.5 and not p1_last_lz
				just_pressed_r = trigger_r > 0.5 and not p1_last_rz
				p1_last_lz = trigger_l > 0.5
				p1_last_rz = trigger_r > 0.5
			else:
				just_pressed_l = trigger_l > 0.5 and not p2_last_lz
				just_pressed_r = trigger_r > 0.5 and not p2_last_rz
				p2_last_lz = trigger_l > 0.5
				p2_last_rz = trigger_r > 0.5
			return just_pressed_r or just_pressed_l
	else:
		if is_p1:
			return Input.is_joy_button_pressed(player_idx, JOY_BUTTON_A) or Input.is_action_pressed("game_main_button")
		else:
			return Input.is_joy_button_pressed(player_idx, JOY_BUTTON_A) or Input.is_action_pressed("game_main_button_2")

func update_oxygen(delta: float) -> void:
	var p1_decay = oxygen_decay_rate
	var p2_decay = oxygen_decay_rate
	var p1_recover = oxygen_recover_rate
	var p2_recover = oxygen_recover_rate

	# Lungs missing
	if not p1_organs["lungs"]:
		p1_decay *= 1.3
		p1_recover *= 0.7
	if not p2_organs["lungs"]:
		p2_decay *= 1.3
		p2_recover *= 0.7

	# Mouth missing
	if not p1_organs["mouth"]:
		p1_decay *= 1.2
	if not p2_organs["mouth"]:
		p2_decay *= 1.2

	# P1 oxygen - only decay when underwater (not at surface)
	if not p1_at_surface:
		p1_oxygen -= p1_decay * delta
	else:
		p1_oxygen = minf(p1_oxygen + p1_recover * delta, max_oxygen)

	# P2 oxygen
	if not p2_at_surface:
		p2_oxygen -= p2_decay * delta
	else:
		p2_oxygen = minf(p2_oxygen + p2_recover * delta, max_oxygen)

	p1_oxygen = clampf(p1_oxygen, 0.0, max_oxygen)
	p2_oxygen = clampf(p2_oxygen, 0.0, max_oxygen)

func update_oxygen_ui() -> void:
	if oxygen_p1:
		oxygen_p1.value = p1_oxygen
		if p1_oxygen < 30:
			oxygen_p1.modulate = Color(1, 0, 0)
		elif p1_oxygen < 60:
			oxygen_p1.modulate = Color(1, 1, 0)
		else:
			oxygen_p1.modulate = Color(0, 1, 0)

	if oxygen_p2:
		oxygen_p2.value = p2_oxygen
		if p2_oxygen < 30:
			oxygen_p2.modulate = Color(1, 0, 0)
		elif p2_oxygen < 60:
			oxygen_p2.modulate = Color(1, 1, 0)
		else:
			oxygen_p2.modulate = Color(0, 1, 0)

	# Update blackout state UI
	_update_blackout_ui()

func _update_blackout_ui() -> void:
	pass

func get_p1_speed_modifier() -> float:
	var mod = 1.0

	if not p1_organs["arms"]:
		mod *= 0.5

	if not p1_organs["legs"]:
		mod *= 0.5

	if not p1_organs["pancreas"]:
		if randf() < 0.01:
			mod *= 0.3
		else:
			mod *= 1.0

	if not p1_organs["liver"] and p1_toxin_level > 65:
		mod *= 0.7

	return mod

func get_p2_speed_modifier() -> float:
	var mod = 1.0

	if not p2_organs["arms"]:
		mod *= 0.5

	if not p2_organs["legs"]:
		mod *= 0.5

	if not p2_organs["pancreas"]:
		if randf() < 0.01:
			mod *= 0.3
		else:
			mod *= 1.0

	if not p2_organs["liver"] and p2_toxin_level > 65:
		mod *= 0.7

	return mod

func update_depths(delta: float) -> void:
	var p1_input_down = _check_swim_input(0, true)
	var p2_input_down = _check_swim_input(1, false)

	# Check for blackout state - block all inputs except heart restart (A button)
	if organ_global_effects:
		if organ_global_effects.is_player_blackout(0):
			# P1 is blacked out - only allow A button through for heart restart
			# All other inputs are blocked
			p1_input_down = false
		if organ_global_effects.is_player_blackout(1):
			# P2 is blacked out - only allow A button through for heart restart
			p2_input_down = false

	# Apply liver mirrored controls
	if not p1_organs["liver"] and p1_toxin_level > 65:
		p1_input_down = not p1_input_down
	if not p2_organs["liver"] and p2_toxin_level > 65:
		p2_input_down = not p2_input_down

	# Determine if at surface
	p1_at_surface = p1_depth < 50
	p2_at_surface = p2_depth < 50

	# Calculate swim speeds with organ modifiers
	var p1_speed = swim_speed * get_p1_speed_modifier()
	var p2_speed = swim_speed * get_p2_speed_modifier()

	# Additional legs penalty when not at surface
	if not p1_organs["legs"] and not p1_at_surface:
		p1_speed *= 0.7
	if not p2_organs["legs"] and not p2_at_surface:
		p2_speed *= 0.7

	# Swimming down uses oxygen
	if p1_input_down and p1_oxygen > 0:
		p1_depth += p1_speed * delta
	elif not p1_input_down:
		p1_depth -= p1_speed * 0.3 * delta
		if p1_depth < 0:
			p1_depth = 0

	if p2_input_down and p2_oxygen > 0:
		p2_depth += p2_speed * delta
	elif not p2_input_down:
		p2_depth -= p2_speed * 0.3 * delta
		if p2_depth < 0:
			p2_depth = 0

	# Clamp depth
	p1_depth = clampf(p1_depth, 0.0, target_depth * 1.2)
	p2_depth = clampf(p2_depth, 0.0, target_depth * 1.2)

	# Update player positions
	p1.position.y = p1_depth
	p2.position.y = p2_depth

	# Update anchor position
	anchor.position.y = target_depth

func update_camera(delta: float) -> void:
	if not camera:
		return

	var target_y: float = maxf(p1_depth, p2_depth)
	var center_y: float = target_y + 200.0

	var target_pos: Vector2 = Vector2(540, center_y)
	camera.position = camera.position.lerp(target_pos, 2.0 * delta)

	var max_depth: float = maxf(p1_depth, p2_depth)
	var zoom_level: float = clampf(0.3 + (max_depth / 2000.0), 0.3, 0.8)
	camera.zoom = camera.zoom.lerp(Vector2(zoom_level, zoom_level), 1.5 * delta)

func update_fish(delta: float) -> void:
	fish_spawn_timer += delta
	if fish_spawn_timer >= fish_spawn_interval and fishes.size() < max_fish:
		_spawn_fish()
		fish_spawn_timer = 0.0
		fish_spawn_interval = randf_range(3.0, 7.0)

	for fish in fishes:
		if is_instance_valid(fish):
			fish.update_position(delta)

func _spawn_fish() -> void:
	if fish_scene == null:
		return

	var fish_instance = fish_scene.instantiate()
	fish_container.add_child(fish_instance)

	var fish_max_depth: float = maxf(p1_depth, p2_depth)
	var spawn_depth: float = fish_max_depth - 200.0 if fish_max_depth > 200.0 else 100.0
	spawn_depth = clampf(spawn_depth, 50.0, target_depth * 0.7)

	var spawn_x = randf_range(100, 600)
	fish_instance.spawn(spawn_depth, target_depth, spawn_x)
	fishes.append(fish_instance)

func check_fish_collisions() -> void:
	for fish in fishes:
		if not is_instance_valid(fish):
			continue

		var fish_pos = fish.position

		var p1_pos = p1.position
		var distance = (fish_pos - p1_pos).length()
		if distance < 50 and not fish.hit_p1:
			fish.hit_p1 = true
			p1_oxygen -= 15.0
			p1_depth -= 30.0

		var p2_pos = p2.position
		distance = (fish_pos - p2_pos).length()
		if distance < 50 and not fish.hit_p2:
			fish.hit_p2 = true
			p2_oxygen -= 15.0
			p2_depth -= 30.0

func check_win_condition() -> void:
	var p1_wins = false
	var p2_wins = false

	if p1_depth >= target_depth:
		p1_wins = true
	if p2_depth >= target_depth:
		p2_wins = true

	if p1_oxygen <= 0.0 and p1_depth > 100.0:
		p1_wins = false
	if p2_oxygen <= 0.0 and p2_depth > 100.0:
		p2_wins = false

	if p1_wins and not p2_wins:
		end_game("0")
	elif p2_wins and not p1_wins:
		end_game("1")
	elif p1_wins and p2_wins:
		if p1_depth >= p2_depth:
			end_game("0")
		else:
			end_game("1")

func end_game(winner: String) -> void:
	if game_ended:
		return
	game_ended = true
	game_started = false
	current_state = GameState.ENDED

	var winner_idx = winner.to_int() + 1
	gamestate["last_winner"] = str(winner_idx)
	gamestate["players"]["p" + str(winner_idx)]["score"] += 1
	gamestate["players"]["p" + str(winner_idx)]["money"] += 300
	write_json(gamestate)

	duration_timer.start()

func _on_duration_timer_timeout() -> void:
	var winner = "0" if p1_depth >= p2_depth else "1"
	end_game(winner)

func _load_organ_states() -> void:
	if "organs" in gamestate.get("players", {}).get("p1", {}):
		var organs = gamestate["players"]["p1"]["organs"]
		p1_organs["lungs"] = organs.get("lungs", true)
		p1_organs["heart"] = organs.get("heart", true)
		p1_organs["arms"] = organs.get("arms", true)
		p1_organs["legs"] = organs.get("legs", true)
		p1_organs["liver"] = organs.get("liver", true)
		p1_organs["pancreas"] = organs.get("pancreas", true)
		p1_organs["mouth"] = organs.get("mouth", true)
		p1_organs["eyes"] = organs.get("eyes", true)

	if "organs" in gamestate.get("players", {}).get("p2", {}):
		var organs = gamestate["players"]["p2"]["organs"]
		p2_organs["lungs"] = organs.get("lungs", true)
		p2_organs["heart"] = organs.get("heart", true)
		p2_organs["arms"] = organs.get("arms", true)
		p2_organs["legs"] = organs.get("legs", true)
		p2_organs["liver"] = organs.get("liver", true)
		p2_organs["pancreas"] = organs.get("pancreas", true)
		p2_organs["mouth"] = organs.get("mouth", true)
		p2_organs["eyes"] = organs.get("eyes", true)

func open_json(path: String) -> void:
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = file.get_as_text()
		var json_object = JSON.new()
		json_object.parse(json)
		gamestate = json_object.data
		file.close()
	else:
		gamestate = {
			"players": {
				"p1": {"score": 0, "money": 0, "organs": {"lungs": true, "heart": true, "arms": true, "legs": true, "liver": true, "pancreas": true, "mouth": true, "eyes": true}},
				"p2": {"score": 0, "money": 0, "organs": {"lungs": true, "heart": true, "arms": true, "legs": true, "liver": true, "pancreas": true, "mouth": true, "eyes": true}}
			},
			"last_winner": "0"
		}

func write_json(state: Dictionary) -> void:
	var file = FileAccess.open("res://game_state.json", FileAccess.WRITE)
	var json_text = JSON.stringify(state, '\t')
	file.store_string(json_text)
	file.close()
