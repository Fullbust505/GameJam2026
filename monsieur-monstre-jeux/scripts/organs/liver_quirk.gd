class_name LiverQuirk
extends OrganQuirk

## LIVER - Detoxification System
## Cannot filter toxins. Don't press ANY input to detox.

signal toxin_level_changed(level: float)
signal antidote_used(remaining: int)
signal drunk_logic_activated()
signal drunk_logic_deactivated()

@export var toxin_build_rate: float = 3.0  # % per second when pressing input
@export var toxin_decay_rate: float = 5.0  # % per second when doing NOTHING
@export var drunk_threshold: float =65.0  # % toxin for control mirroring
@export var max_antidote_uses: int = 3

var toxin_level: float = 0.0
var antidote_uses: int = max_antidote_uses
var is_intoxicated: bool = false
var controls_mirrored: bool = false
var mirror_timer: float = 0.0
var no_input_time: float = 0.0
var last_input_time: float = 0.0

func _init() -> void:
	super._init()
	organ_name = "Liver"
	is_missing = false

func _process(delta: float) -> void:
	if not is_missing or not is_active:
		return

	# Check if any input is being pressed
	var any_input = _check_any_input()

	if any_input:
		# Build toxin when pressing any input
		toxin_level += toxin_build_rate * delta
		last_input_time = Time.get_ticks_msec() / 1000.0
	else:
		# Decrease toxin when doing nothing (after brief delay)
		no_input_time += delta
		if no_input_time >= 1.0:  # 1 second of no input before detox starts
			toxin_level -= toxin_decay_rate * delta
			toxin_level = max(toxin_level, 0.0)

	toxin_level = clamp(toxin_level, 0.0, 100.0)
	toxin_level_changed.emit(toxin_level)
	_notify_global_effects("toxin_changed")

	# Check for drunk logic threshold
	if toxin_level >= drunk_threshold and not controls_mirrored:
		activate_drunk_logic()
	elif toxin_level < drunk_threshold and controls_mirrored:
		deactivate_drunk_logic()

	# Mirror controls randomly when drunk
	if controls_mirrored:
		mirror_timer += delta
		if mirror_timer > 5.0:
			controls_mirrored = randi() % 2 == 1
			mirror_timer = 0.0

func _check_any_input() -> bool:
	# Check all gamepad buttons
	for i in range(16):
		if Input.is_joy_button_pressed(player_index, i):
			return true
	# Check sticks
	if abs(Input.get_joy_axis(player_index, JOY_AXIS_LEFT_X)) > 0.2:
		return true
	if abs(Input.get_joy_axis(player_index, JOY_AXIS_LEFT_Y)) > 0.2:
		return true
	if abs(Input.get_joy_axis(player_index, JOY_AXIS_RIGHT_X)) > 0.2:
		return true
	if abs(Input.get_joy_axis(player_index, JOY_AXIS_RIGHT_Y)) > 0.2:
		return true
	return false

func handle_input(player_idx: int, delta: float) -> void:
	super.handle_input(player_idx, delta)
	if not is_missing or not is_active:
		return

	# X button = 2
	if Input.is_joy_button_pressed(player_idx, 2):
		use_antidote()

func use_antidote() -> void:
	if antidote_uses > 0:
		antidote_uses -= 1
		toxin_level = 0.0
		deactivate_drunk_logic()
		antidote_used.emit(antidote_uses)
		toxin_level_changed.emit(toxin_level)

func activate_drunk_logic() -> void:
	controls_mirrored = true
	is_intoxicated = true
	drunk_logic_activated.emit()
	_notify_global_effects("drunk_activated")

func deactivate_drunk_logic() -> void:
	controls_mirrored = false
	is_intoxicated = false
	drunk_logic_deactivated.emit()
	_notify_global_effects("drunk_deactivated")

func _notify_global_effects(action: String) -> void:
	var global_effects = get_node_or_null("/root/OrganGlobalEffects")
	if not global_effects:
		return
	match action:
		"toxin_changed":
			global_effects.on_liver_toxicity_changed(player_index, toxin_level, is_intoxicated)
		"drunk_activated":
			global_effects.on_liver_drunk_activated(player_index)
		"drunk_deactivated":
			global_effects.on_liver_drunk_deactivated(player_index)

func get_mirrored_input(input_vector: Vector2) -> Vector2:
	if controls_mirrored:
		return Vector2(-input_vector.x, -input_vector.y)
	return input_vector

func get_status() -> Dictionary:
	return {
		"organ_name": organ_name,
		"is_missing": is_missing,
		"toxin_level": toxin_level,
		"antidote_uses": antidote_uses,
		"is_intoxicated": is_intoxicated,
		"controls_mirrored": controls_mirrored
	}
