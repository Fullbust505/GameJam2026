class_name OrganQuirk
extends Node
## Base class for all organ quirks. Each organ has unique QTE mechanics.

signal quirk_activated(quirk_name: String)
signal quirk_deactivated(quirk_name: String)
signal organ_failed(organ_name: String)
signal organ_efficiency_changed(efficiency: float)

@export var organ_name: String = "Unknown"
@export var is_missing: bool = false
@export var efficiency: float = 1.0 : set = _set_efficiency

var player_index: int = 0
var is_active: bool = false

func _init() -> void:
	pass

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass

func activate() -> void:
	is_active = true

func deactivate() -> void:
	is_active = false

func get_efficiency() -> float:
	return efficiency

func _set_efficiency(value: float) -> void:
	efficiency = clamp(value, 0.0, 1.0)
	organ_efficiency_changed.emit(efficiency)

## Override in subclasses to return current organ status
func get_status() -> Dictionary:
	return {
		"organ_name": organ_name,
		"is_missing": is_missing,
		"efficiency": efficiency,
		"is_active": is_active
	}

## Override to handle gamepad input specific to this organ
func handle_input(player_idx: int, delta: float) -> void:
	player_index = player_idx
