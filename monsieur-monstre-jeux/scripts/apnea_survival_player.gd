extends Node2D

## Player movement script for Apnea Survival minigame.
## Handles swimming, buoyancy physics, air management, and fish collisions.

const OrganConst = preload("res://scripts/core/organ_constants.gd")

# Player identifier
@export var player_id: int = 1

# Movement state
var velocity: Vector2 = Vector2.ZERO
var air_level: float = 100.0  # 0-100 percentage
var damage_count: int = 0
var is_eliminated: bool = false
var has_surfaced_flag: bool = false

# Player organs reference (set by minigame controller)
var player_organs: Node = null

# Level bounds
var _surface_y: float = 80.0
var _level_bottom: float = 600.0
var _level_width: float = 640.0

# Movement constants
const HORIZONTAL_SPEED: float = 200.0
const VERTICAL_SWIM_FORCE: float = 400.0
const FRICTION: float = 0.92
const BASE_BUOYANCY: float = 80.0  # Upward force per second when at 100% air
const GRAVITY_WHEN_NO_AIR: float = 150.0  # Extra downward gravity when air depleted

# Air depletion
const BASE_AIR_DRAIN: float = 5.0  # % per second

# Buoyancy calculation
var lungs_factor: float = 1.0
var buoyancy_force: float = 0.0

# Bubble collection radius
const BUBBLE_COLLECT_RADIUS: float = 25.0

# Invulnerability after fish hit (frames)
var invulnerable_frames: int = 0

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	if is_eliminated:
		return
	
	_process_input(delta)
	_apply_buoyancy(delta)
	_apply_gravity(delta)
	_apply_velocity(delta)
	_update_air_level(delta)
	_check_boundaries()
	
	if invulnerable_frames > 0:
		invulnerable_frames -= 1

## Process player input for movement
func _process_input(delta: float) -> void:
	var horizontal_input = 0.0
	var vertical_input = 0.0
	
	# Player 1: WASD
	# Player 2: Arrow keys
	if player_id == 1:
		if Input.is_action_pressed("p1_left") or Input.is_key_pressed(KEY_A):
			horizontal_input -= 1.0
		if Input.is_action_pressed("p1_right") or Input.is_key_pressed(KEY_D):
			horizontal_input += 1.0
		if Input.is_action_pressed("p1_up") or Input.is_key_pressed(KEY_W):
			vertical_input -= 1.0  # Swim up
		if Input.is_action_pressed("p1_down") or Input.is_key_pressed(KEY_S):
			vertical_input += 1.0  # Swim down (fight buoyancy)
	elif player_id == 2:
		if Input.is_action_pressed("p2_left") or Input.is_key_pressed(KEY_LEFT):
			horizontal_input -= 1.0
		if Input.is_action_pressed("p2_right") or Input.is_key_pressed(KEY_RIGHT):
			horizontal_input += 1.0
		if Input.is_action_pressed("p2_up") or Input.is_key_pressed(KEY_UP):
			vertical_input -= 1.0  # Swim up
		if Input.is_action_pressed("p2_down") or Input.is_key_pressed(KEY_DOWN):
			vertical_input += 1.0  # Swim down
	
	# Apply horizontal movement
	velocity.x = horizontal_input * HORIZONTAL_SPEED
	
	# Apply vertical swimming force (swim down to fight buoyancy)
	if vertical_input > 0:
		velocity.y += VERTICAL_SWIM_FORCE * delta
	elif vertical_input < 0:
		# Swimming up - less buoyancy effect
		velocity.y -= VERTICAL_SWIM_FORCE * 0.5 * delta
	else:
		# Neutral - let buoyancy take over
		pass

## Calculate and apply buoyancy based on air in lungs
func _apply_buoyancy(delta: float) -> void:
	# Buoyancy is proportional to air level
	# More air = more upward force
	var air_factor = air_level / 100.0
	
	# Get lungs bonus from organs
	lungs_factor = 1.0
	if player_organs and is_instance_valid(player_organs):
		if player_organs.has_method("get_lungs_buoyancy_factor"):
			lungs_factor = player_organs.get_lungs_buoyancy_factor()
	
	buoyancy_force = BASE_BUOYANCY * air_factor * lungs_factor
	
	# Apply upward buoyancy (negative Y is up in Godot)
	velocity.y -= buoyancy_force * delta

## Apply gravity when air is low
func _apply_gravity(delta: float) -> void:
	if air_level <= 0:
		# No air = sinking fast
		velocity.y += GRAVITY_WHEN_NO_AIR * delta
	else:
		# Normal weak gravity
		velocity.y += 20.0 * delta

## Apply velocity to position
func _apply_velocity(delta: float) -> void:
	position += velocity * delta
	
	# Apply friction to horizontal velocity
	velocity.x *= FRICTION

## Update air level over time
func _update_air_level(delta: float) -> void:
	# Air depletes based on organ bonuses
	var drain_rate = BASE_AIR_DRAIN
	
	if player_organs and is_instance_valid(player_organs):
		if player_organs.has_method("get_oxygen_drain_rate"):
			drain_rate = player_organs.get_oxygen_drain_rate()
	
	air_level = clamp(air_level - drain_rate * delta, 0.0, 100.0)

## Check level boundaries
func _check_boundaries() -> void:
	# Horizontal bounds
	position.x = clamp(position.x, 20, _level_width - 20)
	
	# Mark as surfaced if above water line
	if position.y < _surface_y:
		has_surfaced_flag = true

## Collect a bubble to restore air
func collect_bubble() -> void:
	var air_restore = 25.0
	air_level = clamp(air_level + air_restore, 0.0, 100.0)
	print("[ApneaSurvival] Player %d collected bubble, air now: %.1f" % [player_id, air_level])

## Handle fish collision
func take_damage() -> void:
	if invulnerable_frames > 0:
		return
	
	damage_count += 1
	invulnerable_frames = 60  # 1 second at 60fps
	
	# Visual feedback - flash the player
	self_modulate = Color(1.5, 0.5, 0.5, 1.0)
	await get_tree().create_timer(0.2).timeout
	self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	print("[ApneaSurvival] Player %d hit by fish, damage: %d/2" % [player_id, damage_count])

## Check collision with bubbles in the bubble container
func check_bubble_collection(bubble_container: Node) -> void:
	if not bubble_container:
		return
	
	for bubble in bubble_container.get_children():
		if not is_instance_valid(bubble):
			continue
		
		var dist = position.distance_to(bubble.position)
		if dist < BUBBLE_COLLECT_RADIUS:
			if bubble.has_method("collect"):
				bubble.collect()
			collect_bubble()

## Public getters
func get_air_level() -> float:
	return air_level

func get_damage_count() -> int:
	return damage_count

func has_surfaced() -> bool:
	return has_surfaced_flag

func is_player_eliminated() -> bool:
	return is_eliminated

## Setters
func set_player_organs(organs_node: Node) -> void:
	player_organs = organs_node

func set_level_bounds(surface: float, bottom: float, width: float) -> void:
	_surface_y = surface
	_level_bottom = bottom
	_level_width = width

func set_eliminated(value: bool) -> void:
	is_eliminated = value

func reset_for_new_game() -> void:
	velocity = Vector2.ZERO
	air_level = 100.0
	damage_count = 0
	is_eliminated = false
	has_surfaced_flag = false
	invulnerable_frames = 0
	position = Vector2(150 if player_id == 1 else 450, _level_bottom - 100)
	self_modulate = Color(1.0, 1.0, 1.0, 1.0)