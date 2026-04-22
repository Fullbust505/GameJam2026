class_name BrainRetrieval
extends Node

## BRAIN - Life-or-Death System
## Player IS the brain. When any organ is lost, you have ONE turn to retrieve it or die.

signal retrieval_started(organ_name: String)
signal retrieval_succeeded(organ_name: String)
signal retrieval_failed(organ_name: String)
signal player_died(cause: String)
signal turn_countdown_started(seconds: float)
signal turn_countdown_tick(seconds: float)
signal turn_countdown_expired()

@export var retrieval_time_limit: float = 30.0  # Seconds to complete retrieval minigame
@export var warning_threshold: float = 10.0  # Seconds remaining to show warning

var current_retrieval_organ: String = ""
var is_retrieval_active: bool = false
var retrieval_timer: float = 0.0
var turn_count: int = 0
var max_turns: int = 1  # Only 1 turn!

var player_index: int = 0
var is_player_brain_dead: bool = false

func _init() -> void:
	pass

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if not is_retrieval_active:
		return

	retrieval_timer -= delta
	turn_countdown_tick.emit(retrieval_timer)

	if retrieval_timer <= warning_threshold and retrieval_timer > 0:
		# Play warning animation/effect
		pass

	if retrieval_timer <= 0:
		fail_retrieval()

## Call this when an organ is lost - starts the one-turn retrieval window
func start_retrieval(organ_name: String) -> void:
	if is_player_brain_dead:
		return  # Already dead, no more chances

	current_retrieval_organ = organ_name
	is_retrieval_active = true
	retrieval_timer = retrieval_time_limit
	turn_countdown_started.emit(retrieval_time_limit)
	retrieval_started.emit(organ_name)

## Call this when player successfully completes the retrieval minigame
func complete_retrieval() -> void:
	if not is_retrieval_active:
		return

	is_retrieval_active = false
	retrieval_timer = 0.0
	retrieval_succeeded.emit(current_retrieval_organ)

	# Reset for potential future organ losses
	current_retrieval_organ = ""

## Internal: called when time runs out
func fail_retrieval() -> void:
	if not is_retrieval_active:
		return

	is_retrieval_active = false
	is_player_brain_dead = true  # BRAIN IS DEAD - GAME OVER
	retrieval_timer = 0.0
	retrieval_failed.emit(current_retrieval_organ)
	player_died.emit("brain_death_no_retrieval")
	turn_countdown_expired.emit()

## Check if player is still alive (brain functioning)
func is_alive() -> bool:
	return not is_player_brain_dead

## Check if currently in retrieval mode
func is_in_retrieval() -> bool:
	return is_retrieval_active

## Get remaining time
func get_remaining_time() -> float:
	return retrieval_timer

## Get current organ being retrieved
func get_current_organ() -> String:
	return current_retrieval_organ

## Revive player (for continue screens / respawn mechanics)
func revive_player() -> void:
	is_player_brain_dead = false
	current_retrieval_organ = ""
	is_retrieval_active = false
	retrieval_timer = 0.0

## For testing: simulate organ loss to trigger retrieval
func simulate_organ_loss(organ_name: String) -> void:
	start_retrieval(organ_name)

## Get status for UI
func get_status() -> Dictionary:
	return {
		"is_alive": is_alive(),
		"is_retrieval_active": is_retrieval_active,
		"current_organ": current_retrieval_organ,
		"remaining_time": retrieval_timer,
		"max_time": retrieval_time_limit
	}
