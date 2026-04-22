class_name ArmsQuirk
extends OrganQuirk

## ARMS - Upper Mobility System
## Cannot grip, throw, or perform fine motor tasks.

signal tremor_activated()
signal tremor_deactivated()
signal item_dropped(item: Node)
signal grip_restored()
signal hand_switched(which: int)
signal throw_power_ready()

@export var tremor_threshold: float = 0.3  # Movement threshold to trigger tremor
@export var drop_chance_per_sec: float = 0.1  # 10% chance per second when holding
@export var steady_mode_slowdown: float = 0.5  # 50% slower when steadying

var is_tremoring: bool = false
var is_holding_item: bool = false
var held_item: Node = null
var current_hand: int = 0  # 0 = left, 1 = right
var grip_quality: float = 1.0
var is_steadying: bool = false
var is_throwing: bool = false
var throw_power: float = 0.0
var throw_charge_time: float = 1.0
var can_overarm_throw: bool = false
var last_lt_pressed: bool = false
var last_lb_pressed: bool = false
var last_rb_pressed: bool = false
var last_a_pressed: bool = false
var last_x_pressed: bool = false

func _init() -> void:
	super._init()
	organ_name = "Arms"
	is_missing = false

func _process(delta: float) -> void:
	if not is_missing or not is_active:
		return

	# Check for tremor based on movement
	var left_x = Input.get_joy_axis(player_index, JOY_AXIS_LEFT_X)
	var left_y = Input.get_joy_axis(player_index, JOY_AXIS_LEFT_Y)
	var movement_magnitude = sqrt(left_x * left_x + left_y * left_y)

	if movement_magnitude > tremor_threshold and not is_steadying:
		activate_tremor()
	else:
		deactivate_tremor()

	# Random drop chance when holding
	if is_holding_item and randf() < drop_chance_per_sec * delta:
		drop_item()

	# Handle throw charge
	if is_throwing:
		throw_power += delta / throw_charge_time
		throw_power = clamp(throw_power, 0.0, 1.0)
		if throw_power >= 1.0:
			throw_power_ready.emit()

func handle_input(player_idx: int, delta: float) -> void:
	super.handle_input(player_idx, delta)
	if not is_missing or not is_active:
		return

	# LT = JOY_BUTTON_LT = 4 (used as button when held)
	var lt_pressed = Input.is_joy_button_pressed(player_idx, 4)

	# LB = 9, RB = 10
	var lb_pressed = Input.is_joy_button_pressed(player_idx, 9)
	var rb_pressed = Input.is_joy_button_pressed(player_idx, 10)

	# A = 0, X = 2
	var a_pressed = Input.is_joy_button_pressed(player_idx, 0)
	var x_pressed = Input.is_joy_button_pressed(player_idx, 2)

	# Steadying hands - edge trigger on LT
	if lt_pressed and not last_lt_pressed:
		is_steadying = true
		activate_tremor()
	elif not lt_pressed:
		is_steadying = false

	# Switch hands - edge trigger
	if lb_pressed and not last_lb_pressed:
		switch_hand(0)  # Left hand
	elif rb_pressed and not last_rb_pressed:
		switch_hand(1)  # Right hand

	# A = 0, X = 2 - both pressed for overarm throw
	if a_pressed and x_pressed and not last_a_pressed:
		attempt_overarm_throw()

	# A button tap for grip - edge trigger
	if a_pressed and not last_a_pressed:
		attempt_grip()

	# Update last states
	last_lt_pressed = lt_pressed
	last_lb_pressed = lb_pressed
	last_rb_pressed = rb_pressed
	last_a_pressed = a_pressed
	last_x_pressed = x_pressed

func attempt_grip() -> void:
	if is_holding_item:
		# Release grip
		pass
	else:
		# Attempt to grip - tap rapidly to secure
		var grip_attempts = 0
		for i in range(5):
			if Input.is_joy_button_pressed(player_index, 0):
				grip_attempts += 1
		grip_quality = grip_attempts / 5.0
		if grip_quality >= 0.6:
			is_holding_item = true
			grip_restored.emit()

func drop_item() -> void:
	if held_item and is_holding_item:
		item_dropped.emit(held_item)
		is_holding_item = false
		held_item = null

func switch_hand(which: int) -> void:
	current_hand = which
	hand_switched.emit(current_hand)

func attempt_overarm_throw() -> void:
	if is_holding_item and held_item and can_overarm_throw:
		throw_power = 1.0
		# Release with full power
		item_dropped.emit(held_item)
		is_holding_item = false
		held_item = null
		throw_power = 0.0

func activate_tremor() -> void:
	if not is_tremoring:
		is_tremoring = true
		tremor_activated.emit()
		_notify_global_effects("tremor_activated")

func deactivate_tremor() -> void:
	if is_tremoring and not is_steadying:
		is_tremoring = false
		tremor_deactivated.emit()
		_notify_global_effects("tremor_deactivated")

func get_movement_slowdown() -> float:
	if is_steadying:
		return steady_mode_slowdown
	return 1.0

func get_tremor_offset() -> Vector2:
	if is_tremoring:
		return Vector2(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05))
	return Vector2.ZERO

func get_status() -> Dictionary:
	return {
		"organ_name": organ_name,
		"is_missing": is_missing,
		"is_tremoring": is_tremoring,
		"is_steadying": is_steadying,
		"is_holding_item": is_holding_item,
		"current_hand": current_hand,
		"grip_quality": grip_quality,
		"can_overarm_throw": can_overarm_throw
	}

func _notify_global_effects(action: String) -> void:
	var global_effects = get_node_or_null("/root/OrganGlobalEffects")
	if not global_effects:
		return
	match action:
		"tremor_activated":
			global_effects.on_arms_tremor_activated(player_index)
		"tremor_deactivated":
			global_effects.on_arms_tremor_deactivated(player_index)
