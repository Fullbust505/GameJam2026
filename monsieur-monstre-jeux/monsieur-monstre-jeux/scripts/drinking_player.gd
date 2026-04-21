extends Node2D
class_name DrinkingPlayer

# Drinking Player Controller - Handles individual player drinking mechanics
# Tracks alcohol level, coma state, and liver effects

signal alcohol_changed(player_id: String, level: float)
signal coma_started(player_id: String)
signal coma_ended(player_id: String)
signal drinking(player_id: String)

# Player identification
@export var player_id: String = "p1"
@export var player_index: int = 0

# Alcohol tracking
var alcohol_level: float = 0.0
const MAX_ALCOHOL: float = 100.0
const MIN_ALCOHOL: float = 0.0

# Drinking mechanics
const DRINK_AMOUNT: float = 12.0  # Alcohol gained per drink
const METABOLISM_RATE: float = 2.0  # Alcohol lost per second (base)
const LIVER_BONUS_RATE: float = 1.0  # Additional metabolism per liver count

# Coma detection
const COMA_ALCOHOL_THRESHOLD: float = 80.0
const COMA_DRINK_COUNT_THRESHOLD: int = 3  # 3 drinks in window
const COMA_DRINK_WINDOW: float = 5.0  # 5 second window

# Coma state
var is_in_coma: bool = false
var coma_duration: float = 0.0
const COMA_DURATION_MIN: float = 5.0
const COMA_DURATION_MAX: float = 10.0

# Drinking input tracking
var _drink_times: Array = []  # Timestamps of recent drinks
var _liver_count: int = 0

# Input action names
var _action_name: String = ""

func _ready() -> void:
	# Set action name based on player index
	match player_index:
		0: _action_name = "player1_action"
		1: _action_name = "player2_action"
		2: _action_name = "player3_action"
		3: _action_name = "player4_action"
	
	_update_liver_bonus()

func _process(delta: float) -> void:
	if is_in_coma:
		coma_duration -= delta
		if coma_duration <= 0.0:
			_end_coma()
		return
	
	# Natural metabolism - liver affects this
	var metabolism = METABOLISM_RATE + (_liver_count * LIVER_BONUS_RATE)
	alcohol_level = max(MIN_ALCOHOL, alcohol_level - (metabolism * delta))
	alcohol_changed.emit(player_id, alcohol_level)

func _update_liver_bonus() -> void:
	# Get liver count from PlayerData
	var pd = get_node_or_null("/root/PlayerData")
	if pd:
		_liver_count = pd.get_organ_count("liver")

func get_metabolism_rate() -> float:
	"""Returns current metabolism rate based on liver health."""
	return METABOLISM_RATE + (_liver_count * LIVER_BONUS_RATE)

func drink() -> void:
	"""Called when player presses drink button."""
	if is_in_coma:
		return
	
	# Update liver bonus
	_update_liver_bonus()
	
	# Add alcohol
	var previous_level = alcohol_level
	alcohol_level = min(MAX_ALCOHOL, alcohol_level + DRINK_AMOUNT)
	
	# Track drink time
	var current_time = Time.get_ticks_msec() / 1000.0
	_drink_times.append(current_time)
	
	# Clean old drinks outside window
	_clean_drink_times(current_time)
	
	drinking.emit(player_id)
	alcohol_changed.emit(player_id, alcohol_level)
	
	# Check for coma condition
	_check_coma()

func _clean_drink_times(current_time: float) -> void:
	"""Remove drink timestamps outside the window."""
	var window_start = current_time - COMA_DRINK_WINDOW
	_drink_times = _drink_times.filter(func(t): return t >= window_start)

func _check_coma() -> void:
	"""Check if player should enter coma."""
	# Need to be above alcohol threshold
	if alcohol_level < COMA_ALCOHOL_THRESHOLD:
		return
	
	# Need too many drinks in short time
	if _drink_times.size() >= COMA_DRINK_COUNT_THRESHOLD:
		_start_coma()

func _start_coma() -> void:
	is_in_coma = true
	coma_duration = randf_range(COMA_DURATION_MIN, COMA_DURATION_MAX)
	coma_started.emit(player_id)

func _end_coma() -> void:
	is_in_coma = false
	coma_duration = 0.0
	_drink_times.clear()
	coma_ended.emit(player_id)

func get_alcohol_level() -> float:
	return alcohol_level

func is_comatose() -> bool:
	return is_in_coma

func get_coma_remaining() -> float:
	return coma_duration if is_in_coma else 0.0

func get_drink_rate() -> float:
	"""Returns recent drinks per second."""
	_clean_drink_times(Time.get_ticks_msec() / 1000.0)
	if _drink_times.size() < 2:
		return 0.0
	var window = COMA_DRINK_WINDOW if _drink_times.size() >= 2 else 1.0
	return float(_drink_times.size()) / window

func reset() -> void:
	alcohol_level = MIN_ALCOHOL
	is_in_coma = false
	coma_duration = 0.0
	_drink_times.clear()
	_update_liver_bonus()
