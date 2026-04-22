class_name MouthQuirk
extends OrganQuirk

## MOUTH - Respiratory/Digestion System
## Cannot breathe properly or eat normally.

signal breath_changed(breath_level: float)
signal oxygen_depleted()
signal hyperventilating()
signal cough_started()
signal cough_suppressed()
signal choke_started()
signal choke_recovered()
signal eating_speed_changed(speed: float)

@export var max_breath: float = 15.0  # Max seconds holdable
@export var breath_deplete_rate: float = 1.0  # Per second during minigames
@export var hyperventilate_threshold: float = 0.3  # Seconds between taps
@export var cough_duration: float = 2.0

var breath_level: float = 100.0  # 100% breath
var is_holding_breath: bool = false
var is_hyperventilating: bool = false
var hyperventilate_timer: float = 0.0
var last_breath_tap: float = 0.0
var is_coughing: bool = false
var cough_timer: float = 0.0
var cough_taps_required: int = 8
var current_cough_taps: int = 0
var is_choking: bool = false
var last_b_pressed: bool = false
var last_x_pressed: bool = false
var choke_timer: float = 0.0
var choke_taps_required: int = 5  # B+X together
var current_choke_taps: int = 0
var eat_speed_mult: float = 1.0
var hunger_level: float = 0.0

func _init() -> void:
	super._init()
	organ_name = "Mouth"
	is_missing = false

func _process(delta: float) -> void:
	if not is_missing or not is_active:
		return

	# Handle breathing when holding breath
	if is_holding_breath:
		breath_level -= breath_deplete_rate * delta * 0.1  # Slow drain
		breath_level = clamp(breath_level, 0.0, 100.0)
		breath_changed.emit(breath_level)
		_notify_global_effects("breath_changed")
		if breath_level <= 0:
			oxygen_depleted.emit()

	# Handle hyperventilation
	if is_hyperventilating:
		hyperventilate_timer -= delta
		if hyperventilate_timer <= 0:
			is_hyperventilating = false

	# Handle coughing
	if is_coughing:
		cough_timer -= delta
		if cough_timer <= 0:
			is_coughing = false
			_notify_global_effects("cough_ended")

	# Handle choking
	if is_choking:
		choke_timer -= delta
		if choke_timer <= 0 and current_choke_taps < choke_taps_required:
			choke_recovered.emit()  # Survived but still in trouble
			is_choking = false
			_notify_global_effects("choke_recovered")

	# Random events
	if randf() < 0.003 and not is_coughing and not is_choking:  # ~0.3% per frame
		start_cough()

	if randf() < 0.001 and not is_choking:  # ~0.1% per frame
		start_choke()

func handle_input(player_idx: int, delta: float) -> void:
	super.handle_input(player_idx, delta)
	if not is_missing or not is_active:
		return

	# B button = 1, X button = 2
	var b_pressed = Input.is_joy_button_pressed(player_idx, 1)
	var x_pressed = Input.is_joy_button_pressed(player_idx, 2)

	# Check for B+X (choke recovery) - edge trigger when both first pressed
	if is_choking and b_pressed and x_pressed:
		if (not last_b_pressed or not last_x_pressed):
			current_choke_taps += 1
			if current_choke_taps >= choke_taps_required:
				choke_recovered.emit()
				is_choking = false
				current_choke_taps = 0

	if b_pressed and not last_b_pressed:
		# B just pressed - check for breath tap
		attempt_breath_tap()

	# Handle cough suppression - edge trigger on B press
	if is_coughing and b_pressed and not last_b_pressed:
		current_cough_taps += 1
		if current_cough_taps >= cough_taps_required:
			cough_suppressed.emit()
			is_coughing = false
			current_cough_taps = 0

	last_b_pressed = b_pressed
	last_x_pressed = x_pressed

func attempt_breath_tap() -> void:
	last_breath_tap = Time.get_ticks_msec() / 1000.0
	var time_since_last = Time.get_ticks_msec() / 1000.0 - last_breath_tap

	if is_hyperventilating:
		# Good hyperventilation - clear airways faster
		breath_level = clamp(breath_level + 5.0, 0.0, 100.0)
		hyperventilate_timer = 0.5
	else:
		# Check if rapid enough for hyperventilation
		if time_since_last < hyperventilate_threshold:
			is_hyperventilating = true
			hyperventilate_timer = 2.0
			hyperventilating.emit()

func start_hold_breath() -> void:
	is_holding_breath = true

func stop_hold_breath() -> void:
	is_holding_breath = false

func start_cough() -> void:
	is_coughing = true
	cough_timer = cough_duration
	current_cough_taps = 0
	cough_started.emit()
	_notify_global_effects("cough_started")

func start_choke() -> void:
	is_choking = true
	choke_timer = 3.0
	current_choke_taps = 0
	choke_started.emit()
	_notify_global_effects("choke_started")

func trigger_gobble_mode() -> void:
	# Called during eating minigames
	eat_speed_mult = 3.0
	hunger_level += 10.0  # Eating faster makes you hungrier
	eating_speed_changed.emit(eat_speed_mult)

func stop_gobble_mode() -> void:
	eat_speed_mult = 1.0
	eating_speed_changed.emit(eat_speed_mult)

func get_breath_modifier() -> float:
	if is_hyperventilating:
		return 1.5  # Better O2 efficiency
	elif is_coughing:
		return 0.5  # Harder to breathe
	return 1.0

func get_status() -> Dictionary:
	return {
		"organ_name": organ_name,
		"is_missing": is_missing,
		"breath_level": breath_level,
		"is_holding_breath": is_holding_breath,
		"is_hyperventilating": is_hyperventilating,
		"is_coughing": is_coughing,
		"is_choking": is_choking,
		"eat_speed_mult": eat_speed_mult,
		"hunger_level": hunger_level
	}

func _notify_global_effects(action: String) -> void:
	var global_effects = get_node_or_null("/root/OrganGlobalEffects")
	if not global_effects:
		return
	match action:
		"cough_started":
			global_effects.on_mouth_cough_started(player_index)
		"cough_ended":
			global_effects.on_mouth_cough_ended(player_index)
		"choke_started":
			global_effects.on_mouth_choke_started(player_index)
		"choke_recovered":
			global_effects.on_mouth_choke_recovered(player_index)
		"breath_changed":
			global_effects.on_mouth_breath_changed(player_index, breath_level)
