class_name OrganManager
extends Node

## Manages all organ quirks for a player.
## Coordinates between organs and applies combined effects to minigames.

signal organ_lost(organ_name: String)
signal organ_retrieved(organ_name: String)
signal player_death(cause: String)
signal all_organs_intact()

# Organ quirk instances
var heart: HeartQuirk
var liver: LiverQuirk
var pancreas: PancreasQuirk
var mouth: MouthQuirk
var eyes: EyesQuirk
var arms: ArmsQuirk
var legs: LegsQuirk

var player_index: int = 0
var is_controllable: bool = true

# Game state references
var current_minigame: Node = null

func _init() -> void:
	# Initialize all organ quirks
	heart = HeartQuirk.new()
	liver = LiverQuirk.new()
	pancreas = PancreasQuirk.new()
	mouth = MouthQuirk.new()
	eyes = EyesQuirk.new()
	arms = ArmsQuirk.new()
	legs = LegsQuirk.new()

func _ready() -> void:
	# Add as children so they receive _process
	add_child(heart)
	add_child(liver)
	add_child(pancreas)
	add_child(mouth)
	add_child(eyes)
	add_child(arms)
	add_child(legs)

	# Connect organ failure signals
	heart.consciousness_lost.connect(_on_consciousness_lost)
	liver.organ_failed.connect(_on_organ_failed)

func _process(delta: float) -> void:
	if not is_controllable:
		return

	# NOTE: We don't call organ._process() here because nodes already
	# have their own _process called automatically when in the tree.
	# handle_input is called once per frame to check for held buttons.

	# Update all active organ quirks - only handle input, timers run in their own _process
	var all_organs = [heart, liver, pancreas, mouth, eyes, arms, legs]
	for organ in all_organs:
		if organ.is_missing and organ.is_active:
			organ.handle_input(player_index, delta)

func set_player_index(idx: int) -> void:
	player_index = idx

func set_organ_missing(organ_name: String, missing: bool) -> void:
	match organ_name.to_lower():
		"heart":
			heart.is_missing = missing
			if missing: organ_lost.emit("Heart")
		"liver":
			liver.is_missing = missing
			if missing: organ_lost.emit("Liver")
		"pancreas":
			pancreas.is_missing = missing
			if missing: organ_lost.emit("Pancreas")
		"mouth":
			mouth.is_missing = missing
			if missing: organ_lost.emit("Mouth")
		"eyes":
			eyes.is_missing = missing
			if missing: organ_lost.emit("Eyes")
		"arms":
			arms.is_missing = missing
			if missing: organ_lost.emit("Arms")
		"legs":
			legs.is_missing = missing
			if missing: organ_lost.emit("Legs")

func activate_organ(organ_name: String) -> void:
	match organ_name.to_lower():
		"heart": heart.activate()
		"liver": liver.activate()
		"pancreas": pancreas.activate()
		"mouth": mouth.activate()
		"eyes": eyes.activate()
		"arms": arms.activate()
		"legs": legs.activate()

func deactivate_all_organs() -> void:
	var all_organs = [heart, liver, pancreas, mouth, eyes, arms, legs]
	for organ in all_organs:
		organ.deactivate()

## Get combined speed modifier from all active organs
func get_speed_modifier() -> float:
	var modifier = 1.0
	if heart.is_missing: modifier *= heart.get_rhythm_multiplier()
	if pancreas.is_missing:
		modifier *= pancreas.get_speed_modifier()
	if legs.is_missing: modifier *= legs.get_movement_speed()
	if mouth.is_missing:
		modifier *= mouth.get_breath_modifier()
	return modifier

## Get vision modifier for rendering effects
func get_vision_modifier() -> float:
	if eyes.is_missing:
		return eyes.get_vision_modifier()
	return 1.0

## Get blur amount (0.0 to 0.9) for shader
func get_blur_amount() -> float:
	if eyes.is_missing:
		return eyes.get_blur_amount()
	return 0.0

## Get any tremors for aim/precision mechanics
func get_tremor_offset() -> Vector2:
	if arms.is_missing:
		return arms.get_tremor_offset()
	return Vector2.ZERO

## Check if controls should be mirrored (liver toxicity)
func get_input_modifier() -> Vector2:
	if liver.is_missing and liver.controls_mirrored:
		return Vector2(-1, -1)
	return Vector2(1, 1)

## Get jitter amount for sugar crashes
func get_jitter_amount() -> float:
	if pancreas.is_missing:
		return pancreas.get_jitter_amount()
	return 0.0

## Check if in sugar crash QTE
func is_in_crash_qte() -> bool:
	if pancreas.is_missing:
		return pancreas.is_in_crash_qte()
	return false

## Get crash progress (0.0 to 1.0)
func get_crash_progress() -> float:
	if pancreas.is_missing:
		return pancreas.get_crash_progress()
	return 0.0

## Get current pump count during crash
func get_crash_pumps() -> int:
	if pancreas.is_missing:
		return pancreas.pumps_during_crash
	return 0

## Called when minigame starts - activate appropriate organs
func on_minigame_start(minigame_type: String) -> void:
	current_minigame = get_node(minigame_type)
	activate_all_missing_organs()

func activate_all_missing_organs() -> void:
	var all_organs = [heart, liver, pancreas, mouth, eyes, arms, legs]
	for organ in all_organs:
		if organ.is_missing:
			organ.activate()

## Called when minigame ends
func on_minigame_end() -> void:
	current_minigame = null
	deactivate_all_organs()

## Get all organ statuses for UI
func get_all_status() -> Dictionary:
	return {
		"heart": heart.get_status(),
		"liver": liver.get_status(),
		"pancreas": pancreas.get_status(),
		"mouth": mouth.get_status(),
		"eyes": eyes.get_status(),
		"arms": arms.get_status(),
		"legs": legs.get_status()
	}

## Check if player is conscious
func is_conscious() -> bool:
	if heart.is_missing:
		return heart.is_conscious
	return true

func _on_consciousness_lost() -> void:
	player_death.emit("heart_failure")
	# Notify global effects system if available
	var global_effects = get_node_or_null("/root/OrganGlobalEffects")
	if global_effects:
		global_effects.on_player_consciousness_lost(player_index)

func _on_organ_failed(organ_name: String) -> void:
	player_death.emit(organ_name + "_failure")

## Get missing organ count
func get_missing_organ_count() -> int:
	var count = 0
	var all_organs = [heart, liver, pancreas, mouth, eyes, arms, legs]
	for organ in all_organs:
		if organ.is_missing:
			count += 1
	return count
