class_name PancreasQuirk
extends OrganQuirk

## PANCREAS - Blood Sugar Regulation
## Cannot regulate insulin/glucose. Sugar crash = BLACKOUT QTE!

signal sugar_level_changed(level: float)
signal crash_started()
signal crash_ended()
signal crash_recovered()
signal spike_started()
signal spike_ended()
signal glucose_used(remaining: int)

@export var crash_interval: float = 60.0  # Seconds between crashes
@export var crash_duration: float = 8.0  # Time to complete QTE
@export var spike_duration: float = 10.0
@export var max_glucose_uses: int = 3
@export var pump_interval: float = 0.6  # Rapid tap interval for QTE
@export var pumps_required: int = 12  # Pumps needed to recover from crash

var sugar_level: float = 50.0
var crash_timer: float = 0.0
var spike_timer: float = 0.0
var glucose_uses: int = max_glucose_uses
var is_crashing: bool = false
var is_spiking: bool = false
var is_hungry: bool = false
var pumps_during_crash: int = 0
var last_pump_time: float = 0.0
var pump_in_progress: bool = false

func _init() -> void:
	super._init()
	organ_name = "Pancreas"
	is_missing = false

func _process(delta: float) -> void:
	if not is_missing or not is_active:
		return

	# Track time to next crash
	if not is_crashing and not is_spiking:
		crash_timer += delta
		if crash_timer >= crash_interval:
			start_crash()

	# Handle crash countdown
	if is_crashing:
		crash_timer -= delta
		if crash_timer <= 0:
			# Failed to recover - stay in crash but reduce severity
			pumps_during_crash = 0

	# Handle spike state
	if is_spiking:
		spike_timer -= delta
		if spike_timer <= 0:
			end_spike()

func handle_input(player_idx: int, delta: float) -> void:
	super.handle_input(player_idx, delta)
	if not is_missing or not is_active:
		return

	# Y button = 3
	if Input.is_joy_button_pressed(player_idx, 3):
		if Input.is_action_just_pressed("game_main_button"):
			use_glucose_or_sugar()

	# A button for sugar crash QTE
	if is_crashing and Input.is_joy_button_pressed(player_idx, 0):
		if Input.is_action_just_pressed("game_main_button") or (Time.get_ticks_msec() / 1000.0 - last_pump_time > pump_interval):
			attempt_crash_recovery_pump()

func attempt_crash_recovery_pump() -> void:
	var time_since = Time.get_ticks_msec() / 1000.0 - last_pump_time

	if abs(time_since - pump_interval) < 0.2:  # Good timing
		pumps_during_crash += 2  # Bonus for good timing
	elif time_since < pump_interval * 1.5:
		pumps_during_crash += 1  # Normal pump

	last_pump_time = Time.get_ticks_msec() / 1000.0

	if pumps_during_crash >= pumps_required:
		end_crash()

func use_glucose_or_sugar() -> void:
	if is_crashing and glucose_uses > 0:
		glucose_uses -= 1
		crash_timer = 0.0
		pumps_during_crash = pumps_required  # Instant recovery
		end_crash()
		glucose_used.emit(glucose_uses)
	elif is_hungry:
		sugar_level = clamp(sugar_level + 20.0, 0.0, 100.0)
		is_hungry = false

func start_crash() -> void:
	is_crashing = true
	crash_timer = crash_duration
	pumps_during_crash = 0
	crash_started.emit()

func end_crash() -> void:
	is_crashing = false
	crash_timer = 0.0
	pumps_during_crash = 0
	crash_ended.emit()
	crash_recovered.emit()

func start_spike() -> void:
	is_spiking = true
	spike_timer = spike_duration
	spike_started.emit()

func end_spike() -> void:
	is_spiking = false
	spike_timer = 0.0
	spike_ended.emit()

func trigger_spike() -> void:
	if not is_spiking:
		start_spike()

func get_speed_modifier() -> float:
	if is_crashing:
		return 0.3  # Very slow during crash
	elif is_spiking:
		return 1.5  # Fast during spike
	return 1.0

func get_jitter_amount() -> float:
	if is_spiking:
		return 0.2
	elif is_crashing:
		return 0.3  # Heavy jitter during crash
	return 0.0

func is_in_crash_qte() -> bool:
	return is_crashing

func get_crash_progress() -> float:
	return float(pumps_during_crash) / float(pumps_required)

func get_status() -> Dictionary:
	return {
		"organ_name": organ_name,
		"is_missing": is_missing,
		"sugar_level": sugar_level,
		"is_crashing": is_crashing,
		"crash_timer": crash_timer,
		"pumps_during_crash": pumps_during_crash,
		"pumps_required": pumps_required,
		"is_spiking": is_spiking,
		"spike_timer": spike_timer,
		"glucose_uses": glucose_uses
	}
