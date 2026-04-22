class_name HeartQuirk
extends OrganQuirk

## HEART - Cardiovascular System
## Missing heartbeat, must manually pump blood.

signal pump_completed(perfect: bool)
signal rhythm_changed(new_rhythm: float)
signal burst_ready()
signal consciousness_lost()
signal consciousness_restored()

@export var pump_interval: float = 0.8  # Seconds between required pumps
@export var missed_pumps_for_blackout: int = 3
@export var rhythm_multiplier_min: float = 0.5
@export var rhythm_multiplier_max: float = 2.0

var current_pumps: int = 0
var missed_pumps: int = 0
var last_pump_time: float = 0.0
var current_rhythm: float = 1.0
var perfect_pumps: int = 0
var burst_charges: int = 0
var burst_active: bool = false
var burst_duration: float = 5.0
var burst_timer: float = 0.0
var is_conscious: bool = true
var pump_timing_window: float = 0.3  # Perfect pump window

func _init() -> void:
	super._init()
	organ_name = "Heart"
	is_missing = false

func _process(delta: float) -> void:
	if not is_missing or not is_active:
		return

	# Track rhythm based on pump frequency
	var time_since_pump = Time.get_ticks_msec() / 1000.0 - last_pump_time
	if time_since_pump > pump_interval * 2:
		current_rhythm = rhythm_multiplier_min
	elif time_since_pump < pump_interval * 0.5:
		current_rhythm = rhythm_multiplier_max

	# Burst mode countdown
	if burst_active:
		burst_timer -= delta
		if burst_timer <= 0:
			burst_active = false
			burst_timer = 0.0

	# Check for missed pump
	if Time.get_ticks_msec() / 1000.0 - last_pump_time > pump_interval and last_pump_time > 0:
		missed_pumps += 1
		if missed_pumps >= missed_pumps_for_blackout:
			lose_consciousness()
		last_pump_time = Time.get_ticks_msec() / 1000.0  # Reset to prevent repeated misses

var last_a_pressed = false

# Right joystick pump tracking
enum JoystickPumpState { IDLE, WAITING_DOWN, WAITING_UP }
var joystick_pump_state = JoystickPumpState.IDLE
var last_joystick_y: float = 0.0
var pumps_this_sequence: int = 0

func handle_input(player_idx: int, delta: float) -> void:
	super.handle_input(player_idx, delta)
	if not is_missing or not is_active or not is_conscious:
		return

	# Check if player is in blackout state - only allow heart restart via A button
	var global_effects = get_node_or_null("/root/OrganGlobalEffects")
	if global_effects and global_effects.is_player_blackout(player_idx):
		# During blackout, only A button (heart pump) is allowed
		var a_pressed_blackout = Input.is_joy_button_pressed(player_idx, 0)
		if a_pressed_blackout and not last_a_pressed:
			attempt_pump()
		last_a_pressed = a_pressed_blackout
		return

	# Right joystick up/down for pumping
	var rs_y = Input.get_joy_axis(player_idx, JOY_AXIS_RIGHT_Y)

	# Detect direction changes on right joystick
	var joystick_threshold = 0.5

	if joystick_pump_state == JoystickPumpState.IDLE:
		if rs_y < -joystick_threshold and last_joystick_y >= -joystick_threshold:
			# Moved up - wait for down
			joystick_pump_state = JoystickPumpState.WAITING_DOWN
		elif rs_y > joystick_threshold and last_joystick_y <= joystick_threshold:
			# Moved down first - wait for up
			joystick_pump_state = JoystickPumpState.WAITING_UP

	elif joystick_pump_state == JoystickPumpState.WAITING_DOWN:
		if rs_y > joystick_threshold and last_joystick_y <= joystick_threshold:
			# Completed up->down, that's one pump
			pumps_this_sequence += 1
			if pumps_this_sequence >= 3:
				attempt_pump()
				pumps_this_sequence = 0
			joystick_pump_state = JoystickPumpState.IDLE

	elif joystick_pump_state == JoystickPumpState.WAITING_UP:
		if rs_y < -joystick_threshold and last_joystick_y >= -joystick_threshold:
			# Completed down->up, that's one pump
			pumps_this_sequence += 1
			if pumps_this_sequence >= 3:
				attempt_pump()
				pumps_this_sequence = 0
			joystick_pump_state = JoystickPumpState.IDLE

	last_joystick_y = rs_y

func attempt_pump() -> void:
	var time_since_last = Time.get_ticks_msec() / 1000.0 - last_pump_time

	# Check if within timing window for perfect pump
	if abs(time_since_last - pump_interval) < pump_timing_window:
		perfect_pumps += 1
		pump_completed.emit(true)
		current_pumps += 1
		last_pump_time = Time.get_ticks_msec() / 1000.0

		# Check for burst charge
		if perfect_pumps >= 10 and not burst_active:
			burst_charges += 1
			perfect_pumps = 0
			burst_ready.emit()
	else:
		# Still a pump, but not perfect
		pump_completed.emit(false)
		current_pumps += 1
		missed_pumps = max(0, missed_pumps - 1)  # Partially recover
		last_pump_time = Time.get_ticks_msec() / 1000.0

func activate_burst() -> void:
	if burst_charges > 0 and not burst_active:
		burst_charges -= 1
		burst_active = true
		burst_timer = burst_duration
		quirk_activated.emit("CardioBurst")

func get_rhythm_multiplier() -> float:
	if burst_active:
		return 0.5  # Slow motion when burst active
	return current_rhythm

func lose_consciousness() -> void:
	if not is_conscious:
		return
	is_conscious = false
	consciousness_lost.emit()

	# Notify global effects system if available
	var global_effects = get_node_or_null("/root/OrganGlobalEffects")
	if global_effects:
		global_effects.on_player_consciousness_lost(player_index)

	# Reset after a delay
	await get_tree().create_timer(3.0).timeout
	restore_consciousness()

func restore_consciousness() -> void:
	is_conscious = true
	missed_pumps = 0
	perfect_pumps = 0
	current_rhythm = 1.0
	consciousness_restored.emit()

	# Notify global effects system if available
	var global_effects = get_node_or_null("/root/OrganGlobalEffects")
	if global_effects:
		global_effects.on_player_consciousness_restored(player_index)

func get_status() -> Dictionary:
	return {
		"organ_name": organ_name,
		"is_missing": is_missing,
		"is_conscious": is_conscious,
		"pump_count": current_pumps,
		"missed_pumps": missed_pumps,
		"perfect_pumps": perfect_pumps,
		"burst_charges": burst_charges,
		"burst_active": burst_active,
		"current_rhythm": current_rhythm,
		"rhythm_multiplier": get_rhythm_multiplier()
	}
