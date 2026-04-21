extends OrganChallenge

var required_rate: float = 4.0
var buttons: Array = ["gamepad_l1", "gamepad_r1"]
var last_button_index: int = -1
var last_alternate_time: float = 0.0
var current_rate: float = 0.0
var fail_timer: float = 0.0
var is_failing: bool = false

func _init(p_id: String, p_organ: String, p_config: Dictionary):
	super(p_id, p_organ, p_config)
	required_rate = config.get("required_rate", 4.0)
	buttons = config.get("buttons", ["gamepad_l1", "gamepad_r1"])

func _process(delta: float) -> void:
	if not is_active:
		return

	if is_failing:
		fail_timer += delta
		if fail_timer >= 2.0:
			trigger_warning(1.0)
			is_failing = false
			fail_timer = 0.0

	if current_rate > 0.0:
		var ratio = current_rate / required_rate
		if ratio >= 1.0:
			warning_intensity = 0.0
			is_failing = false
		else:
			warning_intensity = 1.0 - ratio
			if ratio < 0.5:
				is_failing = true

	if current_rate > 0.0:
		current_rate = max(0.0, current_rate - delta * 2.0)

func record_alternate(button_index: int) -> void:
	if button_index != last_button_index:
		var now = Time.get_ticks_msec() / 1000.0
		if last_alternate_time > 0.0:
			var interval = now - last_alternate_time
			if interval > 0.1 and interval < 2.0:
				current_rate = 1.0 / interval
		last_button_index = button_index
		last_alternate_time = now

func get_current_rate() -> float:
	return current_rate

func get_required_rate() -> float:
	return required_rate
