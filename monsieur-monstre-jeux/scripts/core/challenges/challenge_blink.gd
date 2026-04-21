extends OrganChallenge

var interval: float = 5.0
var timer: float = 0.0
var button_name: String = "game_main_button"
var window: float = 1.5
var in_window: bool = false
var has_warned_once: bool = false
var first_warning_done: bool = false

func _init(p_id: String, p_organ: String, p_config: Dictionary):
	super(p_id, p_organ, p_config)
	interval = config.get("interval", 5.0)
	button_name = config.get("button", "game_main_button")

func _process(delta: float) -> void:
	if not is_active:
		return

	timer += delta

	var warning_mode = config.get("warning", "always")

	if warning_mode == "once" and not first_warning_done:
		if timer >= interval - 1.0 and not has_warned_once:
			trigger_warning(1.0)
			has_warned_once = true
			first_warning_done = true
	elif warning_mode == "always":
		var time_left = interval - timer
		if time_left <= 1.0:
			trigger_warning(1.0 - time_left)
		elif time_left <= 2.0:
			trigger_warning((time_left - 1.0) * 0.5)

	if timer >= interval and not in_window:
		in_window = true
		timer = 0.0
	elif in_window and timer >= window:
		_on_fail()
		reset_timer()

func _check_input(event: InputEvent) -> bool:
	if event.is_action_pressed(button_name) and in_window:
		_on_success()
		reset_timer()
		return true
	return false

func reset_timer() -> void:
	timer = 0.0
	in_window = false
	has_warned_once = false
	warning_intensity = 0.0

func is_in_blink_window() -> bool:
	return in_window
