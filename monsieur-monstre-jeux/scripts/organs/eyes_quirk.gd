class_name EyesQuirk
extends OrganQuirk

## EYES - Vision System
## Missing eyes = progressive blur on player's display!

signal echo_ping_activated(duration: float)
signal echo_ended()
signal twitch_started()
signal twitch_ended()
signal bloodshot_activated()
signal bloodshot_cleared()
signal peripheral_movement(direction: Vector2)
signal blur_level_changed(level: float)

@export var echo_duration: float = 3.0
@export var twitch_chance_per_sec: float = 0.15  # 15% per second
@export var twitch_duration: float = 1.0
@export var bloodshot_duration: float = 5.0
@export var blur_build_rate: float = 2.0  # Blur % per second of gameplay
@export var max_blur: float = 90.0  # Maximum blur amount
@export var echo_blur_reduction: float = 30.0  # Blur reduced when using echo ping

var is_echo_active: bool = false
var echo_timer: float = 0.0
var is_twitching: bool = false
var twitch_timer: float = 0.0
var is_bloodshot: bool = false
var bloodshot_timer: float = 0.0
var peripheral_cooldown: float = 0.0
var blur_level: float = 0.0  # Current blur amount (0-100)
var last_peripheral_check: float = 0.0
var echo_pings_used: int = 0

func _init() -> void:
	super._init()
	organ_name = "Eyes"
	is_missing = false

func _process(delta: float) -> void:
	if not is_missing or not is_active:
		return

	# Build blur over time during gameplay
	blur_level += blur_build_rate * delta
	blur_level = clamp(blur_level, 0.0, max_blur)
	blur_level_changed.emit(blur_level)
	_notify_global_effects("blur_changed")

	# Echo ping timer
	if is_echo_active:
		echo_timer -= delta
		# Echo ping reduces blur temporarily
		blur_level = max(0.0, blur_level - echo_blur_reduction * delta)
		if echo_timer <= 0:
			is_echo_active = false
			echo_ended.emit()

	# Eye twitch random trigger
	if not is_twitching and randf() < twitch_chance_per_sec * delta:
		trigger_twitch()

	if is_twitching:
		twitch_timer -= delta
		blur_level += 5.0 * delta  # Twitch makes blur worse
		if twitch_timer <= 0:
			is_twitching = false
			twitch_ended.emit()
			_notify_global_effects("twitch_ended")

	# Bloodshot when hurt - increases blur
	if is_bloodshot:
		bloodshot_timer -= delta
		blur_level += 3.0 * delta  # Bloodshot makes blur worse
		if bloodshot_timer <= 0:
			is_bloodshot = false
			bloodshot_cleared.emit()

	# Peripheral ghost movement check
	peripheral_cooldown -= delta
	if peripheral_cooldown <= 0 and not is_echo_active:
		if randf() < 0.1:
			var direction = Vector2(randf_range(-1, 1), randf_range(-1, 1))
			peripheral_movement.emit(direction)
			peripheral_cooldown = 3.0

	blur_level = clamp(blur_level, 0.0, max_blur)

var last_rs_pressed = false

func handle_input(player_idx: int, delta: float) -> void:
	super.handle_input(player_idx, delta)
	if not is_missing or not is_active:
		return

	# Right stick click = 11 - edge trigger on press
	var rs_pressed = Input.is_joy_button_pressed(player_idx, 11)
	if rs_pressed and not last_rs_pressed:
		attempt_echo_ping()
	last_rs_pressed = rs_pressed

	# Right stick for peripheral look
	var rs_x = Input.get_joy_axis(player_idx, JOY_AXIS_RIGHT_X)
	var rs_y = Input.get_joy_axis(player_idx, JOY_AXIS_RIGHT_Y)
	if abs(rs_x) > 0.5 or abs(rs_y) > 0.5:
		look_at_peripheral(Vector2(rs_x, rs_y))

func attempt_echo_ping() -> void:
	if is_echo_active:
		# Already active, try to extend or refocus
		if is_twitching:
			refocus()
	elif is_twitching:
		refocus()
	else:
		start_echo_ping()

func start_echo_ping() -> void:
	is_echo_active = true
	echo_timer = echo_duration
	echo_pings_used += 1
	# Using echo ping clears some blur temporarily
	blur_level = max(0.0, blur_level - 20.0)
	echo_ping_activated.emit(echo_duration)

func refocus() -> void:
	# Clear twitch and some blur
	twitch_timer = 0.0
	is_twitching = false
	blur_level = max(0.0, blur_level - 10.0)
	twitch_ended.emit()

func activate_bloodshot() -> void:
	is_bloodshot = true
	bloodshot_timer = bloodshot_duration
	bloodshot_activated.emit()

func trigger_twitch() -> void:
	is_twitching = true
	twitch_timer = twitch_duration
	twitch_started.emit()
	_notify_global_effects("twitch_started")

func look_at_peripheral(direction: Vector2) -> void:
	# Confirm or ignore peripheral ghost
	peripheral_movement.emit(direction.normalized())

func get_vision_modifier() -> float:
	# Lower = more blur, affects gameplay visibility
	if is_echo_active:
		return 0.0  # Black screen with echo outlines
	elif is_twitching:
		return clamp(1.0 - (blur_level / 100.0) - 0.3, 0.1, 1.0)
	elif is_bloodshot:
		return clamp(1.0 - (blur_level / 100.0) - 0.2, 0.15, 1.0)
	return clamp(1.0 - (blur_level / 100.0), 0.1, 1.0)

func get_blur_amount() -> float:
	# Returns blur amount (0.0 to 1.0) for shader/renderer
	return blur_level / 100.0

func get_status() -> Dictionary:
	return {
		"organ_name": organ_name,
		"is_missing": is_missing,
		"is_echo_active": is_echo_active,
		"echo_timer": echo_timer,
		"is_twitching": is_twitching,
		"is_bloodshot": is_bloodshot,
		"blur_level": blur_level,
		"vision_modifier": get_vision_modifier(),
		"echo_pings_used": echo_pings_used
	}

func _notify_global_effects(action: String) -> void:
	var global_effects = get_node_or_null("/root/OrganGlobalEffects")
	if not global_effects:
		return
	match action:
		"blur_changed":
			global_effects.on_eyes_blur_changed(player_index, blur_level)
		"twitch_started":
			global_effects.on_eyes_twitch_started(player_index)
		"twitch_ended":
			global_effects.on_eyes_twitch_ended(player_index)
