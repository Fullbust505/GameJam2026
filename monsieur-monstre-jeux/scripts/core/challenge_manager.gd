extends Node

var player_challenges: Dictionary = {}
var warning_overlay: Control = null

signal challenge_warning(player_id, organ, intensity)
signal challenge_failed(player_id, organ)

func _ready() -> void:
	pass

func setup_player(player_id: String, player_data: Dictionary, organ_configs: Dictionary) -> void:
	player_challenges[player_id] = []

	for organ in ["eyes", "arms", "legs", "lungs", "heart", "pancreas"]:
		if not player_data.get("organs", {}).get(organ, true):
			if organ_configs.has(organ):
				var config = organ_configs[organ]
				var challenge = spawn_challenge(player_id, organ, config)
				if challenge:
					player_challenges[player_id].append(challenge)
					add_child(challenge)
					challenge.connect("warning_triggered", _on_challenge_warning)
					challenge.connect("challenge_failed", _on_challenge_failed)

func spawn_challenge(player_id: String, organ: String, config: Dictionary) -> OrganChallenge:
	var type = config.get("type", "")

	match type:
		"periodic_tap":
			return preload("res://scripts/core/challenges/challenge_periodic_tap.gd").new(player_id, organ, config)
		"continuous_alternate":
			return preload("res://scripts/core/challenges/challenge_continuous_alternate.gd").new(player_id, organ, config)
		"joystick_pump":
			return preload("res://scripts/core/challenges/challenge_joystick_pump.gd").new(player_id, organ, config)
		"qte_sequence":
			return preload("res://scripts/core/challenges/challenge_qte_sequence.gd").new(player_id, organ, config)
		"blink":
			return preload("res://scripts/core/challenges/challenge_blink.gd").new(player_id, organ, config)

	return null

func _process(delta: float) -> void:
	for challenges in player_challenges.values():
		for challenge in challenges:
			challenge._process(delta)

func _input(event: InputEvent) -> void:
	for challenges in player_challenges.values():
		for challenge in challenges:
			challenge._check_input(event)

func get_challenges_for_player(player_id: String) -> Array:
	return player_challenges.get(player_id, [])

func get_total_warning_intensity(player_id: String) -> float:
	var total = 0.0
	var challenges = player_challenges.get(player_id, [])
	for c in challenges:
		total += c.get_warning_intensity()
	return min(1.0, total)

func get_challenge_by_organ(player_id: String, organ: String) -> OrganChallenge:
	var challenges = player_challenges.get(player_id, [])
	for c in challenges:
		if c.organ == organ:
			return c
	return null

func clear_player_challenges(player_id: String) -> void:
	var challenges = player_challenges.get(player_id, [])
	for c in challenges:
		c.queue_free()
	player_challenges[player_id] = []

func clear_all() -> void:
	for player_id in player_challenges.keys():
		clear_player_challenges(player_id)
	player_challenges.clear()

func _on_challenge_warning(player_id: String, organ: String, intensity: float) -> void:
	emit_signal("challenge_warning", player_id, organ, intensity)

func _on_challenge_failed(player_id: String, organ: String) -> void:
	emit_signal("challenge_failed", player_id, organ)

func create_warning_overlay(parent: Node) -> Control:
	var overlay = Control.new()
	overlay.name = "WarningOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(overlay)
	warning_overlay = overlay
	return overlay
