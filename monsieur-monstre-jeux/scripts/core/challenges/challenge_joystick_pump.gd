extends OrganChallenge

var interval: float = 10.0
var window: float = 1.0
var axis_name: String = "gamepad_left_axis_y"
var timer: float = 0.0
var waiting_for_up: bool = true
var waiting_for_down: bool = false
var window_timer: float = 0.0
var has_warned_once: bool = false
var first_warning_done: bool = false

func _init(p_id: String, p_organ: String, p_config: Dictionary):
	super(p_id, p_organ, p_config)
	interval = config.get("interval", 10.0)
	window = config.get("window", 1.0)
	axis_name = config.get("axis", "gamepad_left_axis_y")

func _process(delta: float) -> void:
	if not is_active:
		return

	var warning_mode = config.get("warning", "once")

	if warning_mode == "once" and not first_warning_done:
		if timer >= interval - 1.0 and not has_warned_once:
			trigger_warning(1.0)
			has_warned_once = true
			first_warning_done = true

	if waiting_for_up or waiting_for_down:
		window_timer += delta
		if window_timer >= window:
			_on_fail()
			reset_state()
	else:
		timer += delta
		if timer >= interval:
			waiting_for_up = true
			timer = 0.0

func _check_input(event: InputEvent) -> bool:
	if not (waiting_for_up or waiting_for_down):
		return false

	if event.is_action_pressed("gamepad_up"):
		if waiting_for_up:
			waiting_for_up = false
			waiting_for_down = true
			window_timer = 0.0
			return true
	elif event.is_action_pressed("gamepad_down"):
		if waiting_for_down:
			_on_success()
			reset_state()
			return true

	return false

func reset_state() -> void:
	waiting_for_up = false
	waiting_for_down = false
	window_timer = 0.0
	has_warned_once = false
	warning_intensity = 0.0

func is_in_pump_window() -> bool:
	return waiting_for_up or waiting_for_down
