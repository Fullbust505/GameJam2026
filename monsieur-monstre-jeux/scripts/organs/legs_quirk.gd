class_name LegsQuirk
extends OrganQuirk

## LEGS - Lower Mobility System
## Cannot walk, run, or balance properly.

signal crawl_started()
signal crawl_ended()
signal balance_lost()
signal balance_recovered()
signal leg_drag_started()
signal leg_drag_ended()
signal sprint_burst_started()
signal sprint_burst_ended()
signal exhaustion_started()
signal exhaustion_ended()

@export var crawl_speed_mult: float = 0.5
@export var sprint_duration: float = 5.0
@export var exhaustion_duration: float = 20.0
@export var leg_drag_chance_per_sec: float = 0.05  # 5% per second
@export var balance_difficulty: float = 0.7  # How hard it is to balance

var is_crawling: bool = false
var is_balancing: bool = false
var is_on_uneven_surface: bool = false
var balance_quality: float = 1.0
var is_leg_dragging: bool = false
var leg_drag_timer: float = 0.0
var leg_drag_taps_required: int = 10
var current_leg_drag_taps: int = 0
var is_sprinting: bool = false
var sprint_timer: float = 0.0
var is_exhausted: bool = false
var exhaustion_timer: float = 0.0
var last_leg_drag_tap: float = 0.0

func _init() -> void:
	super._init()
	organ_name = "Legs"
	is_missing = false

func _process(delta: float) -> void:
	if not is_missing or not is_active:
		return

	# Handle sprint
	if is_sprinting:
		sprint_timer -= delta
		if sprint_timer <= 0:
			end_sprint()

	# Handle exhaustion
	if is_exhausted:
		exhaustion_timer -= delta
		if exhaustion_timer <= 0:
			is_exhausted = false
			exhaustion_ended.emit()

	# Handle leg drag
	if is_leg_dragging:
		leg_drag_timer -= delta
		if leg_drag_timer <= 0:
			# Failed to recover
			leg_drag_ended.emit()
			is_leg_dragging = false
		else:
			# Check for taps
			var time_since_tap = Time.get_ticks_msec() / 1000.0 - last_leg_drag_tap
			if time_since_tap < 0.5:
				# Alternating A and B taps
				current_leg_drag_taps += 1
				if current_leg_drag_taps >= leg_drag_taps_required:
					leg_drag_ended.emit()
					is_leg_dragging = false
					current_leg_drag_taps = 0

	# Random leg drag trigger
	if not is_leg_dragging and not is_exhausted and randf() < leg_drag_chance_per_sec * delta:
		start_leg_drag()

	# Balance check on uneven surfaces
	if is_on_uneven_surface and is_balancing:
		# Tilt left stick slowly or fall
		var left_x = Input.get_joy_axis(player_index, JOY_AXIS_LEFT_X)
		if abs(left_x) > balance_difficulty:
			lose_balance()
		else:
			balance_quality = 1.0 - (abs(left_x) / balance_difficulty)

func handle_input(player_idx: int, delta: float) -> void:
	super.handle_input(player_idx, delta)
	if not is_missing or not is_active:
		return

	# A = 0, B = 1
	var a_pressed = Input.is_joy_button_pressed(player_idx, 0)
	var b_pressed = Input.is_joy_button_pressed(player_idx, 1)

	# A hold = crawl
	if a_pressed:
		start_crawl()
	else:
		end_crawl()

	# A + B = sprint burst
	if a_pressed and b_pressed:
		if not is_sprinting and not is_exhausted:
			start_sprint()

	# Handle leg drag taps
	if is_leg_dragging:
		if a_pressed and not b_pressed:
			last_leg_drag_tap = Time.get_ticks_msec() / 1000.0
		elif b_pressed and not a_pressed:
			last_leg_drag_tap = Time.get_ticks_msec() / 1000.0

func start_crawl() -> void:
	if not is_crawling:
		is_crawling = true
		crawl_started.emit()

func end_crawl() -> void:
	if is_crawling:
		is_crawling = false
		crawl_ended.emit()

func start_leg_drag() -> void:
	is_leg_dragging = true
	leg_drag_timer = 3.0
	current_leg_drag_taps = 0
	leg_drag_started.emit()

func start_sprint() -> void:
	is_sprinting = true
	sprint_timer = sprint_duration
	sprint_burst_started.emit()

func end_sprint() -> void:
	is_sprinting = false
	is_exhausted = true
	exhaustion_timer = exhaustion_duration
	sprint_burst_ended.emit()
	exhaustion_started.emit()

func enter_uneven_surface() -> void:
	is_on_uneven_surface = true
	is_balancing = true

func exit_uneven_surface() -> void:
	is_on_uneven_surface = false
	is_balancing = false
	balance_quality = 1.0

func lose_balance() -> void:
	is_balancing = false
	balance_lost.emit()

func recover_balance() -> void:
	is_balancing = true
	balance_quality = 0.5
	balance_recovered.emit()

func get_movement_speed() -> float:
	var speed = 1.0
	if is_crawling:
		speed *= crawl_speed_mult
	if is_exhausted:
		speed *= 0.5
	if is_leg_dragging:
		speed *= 0.3
	return speed

func get_status() -> Dictionary:
	return {
		"organ_name": organ_name,
		"is_missing": is_missing,
		"is_crawling": is_crawling,
		"is_balancing": is_balancing,
		"balance_quality": balance_quality,
		"is_leg_dragging": is_leg_dragging,
		"is_sprinting": is_sprinting,
		"is_exhausted": is_exhausted,
		"movement_speed": get_movement_speed()
	}
