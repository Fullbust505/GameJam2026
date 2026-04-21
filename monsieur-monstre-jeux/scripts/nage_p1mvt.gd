extends Node2D

## Player 1 movement controller for the swimming minigame.
## Handles alternating button swimming mechanics with bumpers only.
## P1: L1/R1 bumpers on gamepad 0

const OrganConst = preload("res://scripts/core/organ_constants.gd")

@export var player_index: int = 0  # 0 for P1, 1 for P2

# Movement state
var velocity: Vector2 = Vector2.ZERO
var oxygen: float = 100.0
var player_at_surface: bool = false
var is_drowned: bool = false

# Player organs reference (set by minigame controller)
var player_organs: Node = null

# Alternating button swimming state
var last_button_pressed: String = ""  # "A" or "B"
var alternation_timer: float = 0.0   # Time since last valid alternation
var alternation_speed: float = 0.0    # Tracks rhythm (button presses per second)
var air_catches_remaining: int = 3   # Max 3 catches
var button_press_times: Array = []    # For calculating alternation speed

# Debug/freeze prevention
var frame_count: int = 0
var debug_enabled: bool = false

# Constants - New alternation formula
const MIN_ALTERNATION_INTERVAL: float = 0.08  # Faster response for better feel
const GRAVITY: float = 30.0                   # Weak gravity
const DRIFT_SINK: float = 30.0               # Slow drift down
const SWIM_FORCE: float = 1500.0             # Base swim force
const HORIZONTAL_SPEED: float = 200.0
const FRICTION: float = 0.92                 # Velocity damping

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	frame_count += 1
	
	# Debug output every 60 frames (~1 second)
	if debug_enabled and frame_count % 60 == 0:
		print("P1 frame: ", frame_count, " last_btn: ", last_button_pressed, " vel.y: ", velocity.y)
	
	if is_drowned:
		return
	
	# Guard against invalid delta (can happen if engine is paused or under stress)
	if delta <= 0.0 or delta > 1.0:
		return
	
	var frame_multiplier = 60.0 * delta
	
	_update_organ_effects(delta)
	_update_alternation_mechanic(delta)
	_apply_movement(delta, frame_multiplier)
	_update_oxygen(delta)

## Updates movement based on organ effects (e.g., buoyancy from lungs).
func _update_organ_effects(delta: float) -> void:
	if player_organs and is_instance_valid(player_organs):
		var buoyancy = player_organs.get_lungs_buoyancy_factor()
		velocity.y += buoyancy * delta

func _update_alternation_mechanic(delta: float) -> void:
	alternation_timer += delta
	alternation_speed = lerp(alternation_speed, 0.0, delta * 2.0)
	
	var button_a_pressed = _is_p1_button_a_pressed()
	var button_b_pressed = _is_p1_button_b_pressed()
	
	if button_a_pressed:
		_handle_button_press("A")
	elif button_b_pressed:
		_handle_button_press("B")

## P1 Left Bumper (L1) on gamepad 0
func _is_p1_button_a_pressed() -> bool:
	return Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER)

## P1 Right Bumper (R1) on gamepad 0
func _is_p1_button_b_pressed() -> bool:
	return Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER)

## Handles button press for alternating mechanic.
## New formula: Alternating = 750 upward, Same button = 375 upward
func _handle_button_press(button: String) -> void:
	if alternation_timer < MIN_ALTERNATION_INTERVAL:
		return
	
	var is_alternating = (last_button_pressed != button and last_button_pressed != "")
	
	if is_alternating:
		_swim_up_alternated()
		_update_alternation_speed()
		last_button_pressed = button
		alternation_timer = 0.0
	elif last_button_pressed == button:
		# Same button pressed again - reduced power but still swim up
		_swim_up_same()
		# Keep last_button_pressed as-is to detect next same-press
		alternation_timer = 0.0
	else:
		# No previous button or first press - treat as alternating
		_swim_up_alternated()
		last_button_pressed = button
		alternation_timer = 0.0

func _update_alternation_speed() -> void:
	var now = Time.get_ticks_msec()
	button_press_times.append(now)
	
	# Safely trim array - remove oldest entries if over 10
	while button_press_times.size() > 10:
		button_press_times.remove_at(0)
	
	if button_press_times.size() >= 2:
		var total_interval = 0.0
		for i in range(1, button_press_times.size()):
			total_interval += (button_press_times[i] - button_press_times[i-1]) / 1000.0
		
		var avg_interval = total_interval / (button_press_times.size() - 1)
		if avg_interval > 0:
			alternation_speed = 1.0 / avg_interval

## Alternated press: full half force = 750 upward
func _swim_up_alternated() -> void:
	velocity.y = -(SWIM_FORCE / 2.0)

## Same button press: quarter force = 375 upward (still goes up but slower)
func _swim_up_same() -> void:
	velocity.y = -(SWIM_FORCE / 4.0)

## Applies movement with frame-rate independent gravity and horizontal input.
func _apply_movement(delta: float, frame_multiplier: float) -> void:
	var rb = get_node_or_null("RigidBody2D")
	
	velocity.y += GRAVITY * frame_multiplier
	velocity.y += DRIFT_SINK * frame_multiplier
	
	var horizontal = 0.0
	if Input.is_action_pressed("p1_left") or Input.is_key_pressed(KEY_A):
		horizontal -= 1.0
	if Input.is_action_pressed("p1_right") or Input.is_key_pressed(KEY_D):
		horizontal += 1.0
	velocity.x = horizontal * HORIZONTAL_SPEED
	
	velocity.y = clamp(velocity.y, -1500.0, 1500.0)
	
	if rb and rb is RigidBody2D:
		position += velocity * delta
		rb.position = position
	else:
		position += velocity * delta
	
	velocity.x *= FRICTION

func _update_oxygen(delta: float) -> void:
	if not player_at_surface:
		var drain_rate = 5.0
		if player_organs and is_instance_valid(player_organs):
			drain_rate = player_organs.get_oxygen_drain_rate()
		
		oxygen = clamp(oxygen - drain_rate * delta, 0.0, 100.0)
		
		if oxygen <= 0:
			is_drowned = true

func is_at_surface() -> bool:
	return player_at_surface

func can_catch_air() -> bool:
	return air_catches_remaining > 0 and player_at_surface

func catch_air() -> bool:
	if not can_catch_air():
		return false
	
	air_catches_remaining -= 1
	oxygen = clamp(oxygen + 33.0, 0.0, 100.0)
	return true

func get_air_catches_remaining() -> int:
	return air_catches_remaining

func get_oxygen() -> float:
	return oxygen

func get_velocity() -> Vector2:
	return velocity

func get_alternation_speed() -> float:
	return alternation_speed

func is_player_drowned() -> bool:
	return is_drowned

func set_player_organs(organs_node: Node) -> void:
	player_organs = organs_node

func set_surface_status(surface_status: bool) -> void:
	player_at_surface = surface_status

func reset_for_new_game() -> void:
	frame_count = 0
	last_button_pressed = ""
	alternation_timer = 0.0
	alternation_speed = 0.0
	air_catches_remaining = 3
	velocity = Vector2.ZERO
	oxygen = 100.0
	player_at_surface = false
	is_drowned = false
	button_press_times.clear()
