class_name OrganChallenge
extends Node

var player_id: String
var organ: String
var config: Dictionary

var warning_enabled: bool = true
var warning_intensity: float = 0.0
var is_active: bool = true

signal challenge_failed(player_id, organ)
signal challenge_completed(player_id, organ)
signal warning_triggered(player_id, organ, intensity)

func _init(p_id: String, p_organ: String, p_config: Dictionary):
	player_id = p_id
	organ = p_organ
	config = p_config

func _process(delta: float) -> void:
	pass

func _check_input(event: InputEvent) -> bool:
	return false

func _on_fail() -> void:
	emit_signal("challenge_failed", player_id, organ)

func _on_success() -> void:
	emit_signal("challenge_completed", player_id, organ)

func get_warning_intensity() -> float:
	return warning_intensity

func set_warning_enabled(enabled: bool) -> void:
	warning_enabled = enabled

func trigger_warning(intensity: float = 1.0) -> void:
	warning_intensity = intensity
	emit_signal("warning_triggered", player_id, organ, intensity)

func _process_warning(delta: float) -> void:
	if warning_intensity > 0.0:
		warning_intensity = max(0.0, warning_intensity - delta * 0.5)
