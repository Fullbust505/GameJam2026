extends OrganChallenge

var sequence: Array = ["a", "a", "b"]
var current_index: int = 0
var interval_min: float = 15.0
var interval_max: float = 30.0
var next_trigger_time: float = 0.0
var timer: float = 0.0
var is_active_qte: bool = false
var qte_window: float = 3.0
var qte_timer: float = 0.0
var has_warned_once: bool = false
var first_warning_done: bool = false

signal qte_started(player_id, organ)
signal qte_completed(player_id, organ)
signal qte_failed(player_id, organ)

func _init(p_id: String, p_organ: String, p_config: Dictionary):
	super(p_id, p_organ, p_config)
	sequence = config.get("sequence", ["a", "a", "b"])
	interval_min = config.get("interval_min", 15.0)
	interval_max = config.get("interval_max", 30.0)
	next_trigger_time = randf_range(interval_min, interval_max)

func _process(delta: float) -> void:
	if not is_active:
		return

	var warning_mode = config.get("warning", "always")

	if is_active_qte:
		qte_timer += delta
		if qte_timer >= qte_window:
			emit_signal("qte_failed", player_id, organ)
			_on_fail()
			deactivate_qte()
	else:
		timer += delta

		if warning_mode == "once" and not first_warning_done:
			if timer >= next_trigger_time - 3.0 and not has_warned_once:
				trigger_warning(1.0)
				has_warned_once = true
				first_warning_done = true

		if timer >= next_trigger_time:
			activate_qte()
			timer = 0.0
			next_trigger_time = randf_range(interval_min, interval_max)
			has_warned_once = false

func activate_qte() -> void:
	is_active_qte = true
	current_index = 0
	qte_timer = 0.0
	emit_signal("qte_started", player_id, organ)
	trigger_warning(1.0)

func deactivate_qte() -> void:
	is_active_qte = false
	current_index = 0
	qte_timer = 0.0
	warning_intensity = 0.0
	first_warning_done = false

func get_current_sequence() -> Array:
	return sequence.slice(current_index)

func get_progress() -> float:
	return float(current_index) / float(sequence.size())

func _check_input(event: InputEvent) -> bool:
	if not is_active_qte:
		return false

	var button = _get_button_from_event(event)
	if button == sequence[current_index]:
		current_index += 1
		if current_index >= sequence.size():
			emit_signal("qte_completed", player_id, organ)
			_on_success()
			deactivate_qte()
			return true
	return false

func _get_button_from_event(event: InputEvent) -> String:
	if event.is_action_pressed("game_main_button"):
		return "a"
	if event.is_action_pressed("game_secondary_button"):
		return "b"
	return ""
