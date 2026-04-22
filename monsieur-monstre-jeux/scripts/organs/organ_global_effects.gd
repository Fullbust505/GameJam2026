class_name OrganGlobalEffects
extends Node

## Global singleton for organ failure visual effects.
## Persists across minigames and provides screen-wide overlays per player.
## Each organ has unique visual feedback that affects the player's view.

# Player state tracking (per-player effects)
var player_states: Dictionary = {
	0: {
		"is_blackout": false, "blackout_timer": 0.0,
		"liver_toxic": false, "liver_toxin_level": 0.0,
		"pancreas_crash": false, "crash_pumps": 0, "crash_required": 12,
		"mouth_coughing": false, "mouth_choking": false, "breath_level": 100.0,
		"eyes_blur": 0.0, "eyes_twitching": false,
		"arms_tremor": false, "arms_steadying": false,
		"legs_crawling": false, "legs_exhausted": false, "legs_leg_drag": false
	},
	1: {
		"is_blackout": false, "blackout_timer": 0.0,
		"liver_toxic": false, "liver_toxin_level": 0.0,
		"pancreas_crash": false, "crash_pumps": 0, "crash_required": 12,
		"mouth_coughing": false, "mouth_choking": false, "breath_level": 100.0,
		"eyes_blur": 0.0, "eyes_twitching": false,
		"arms_tremor": false, "arms_steadying": false,
		"legs_crawling": false, "legs_exhausted": false, "legs_leg_drag": false
	}
}

# Visual effect nodes
var p1_overlay: CanvasLayer
var p2_overlay: CanvasLayer
var p1_blackout: ColorRect
var p1_liver_overlay: ColorRect
var p1_pancreas_overlay: ColorRect
var p1_mouth_overlay: ColorRect
var p1_eyes_overlay: ColorRect
var p1_arms_tremor: Node  # Shake node
var p1_legs_overlay: ColorRect

var p2_blackout: ColorRect
var p2_liver_overlay: ColorRect
var p2_pancreas_overlay: ColorRect
var p2_mouth_overlay: ColorRect
var p2_eyes_overlay: ColorRect
var p2_legs_overlay: ColorRect

var _is_initialized: bool = false
var _effect_timer: float = 0.0  # Accumulated time for pulse effects

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_overlays()
	_is_initialized = true

func _create_overlays() -> void:
	# P1 Canvas Layer (player 1's view)
	p1_overlay = CanvasLayer.new()
	p1_overlay.name = "P1OrganOverlay"
	p1_overlay.layer = 50
	add_child(p1_overlay)

	# P2 Canvas Layer (player 2's view)
	p2_overlay = CanvasLayer.new()
	p2_overlay.name = "P2OrganOverlay"
	p2_overlay.layer = 50
	add_child(p2_overlay)

	# Create P1 overlays
	_create_player_overlays(0, p1_overlay)
	# Create P2 overlays
	_create_player_overlays(1, p2_overlay)

func _create_player_overlays(player_idx: int, parent: CanvasLayer) -> void:
	# Blackout overlay - deep red/black when heart fails
	var blackout = ColorRect.new()
	blackout.name = "BlackoutOverlay"
	blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	blackout.color = Color(0.05, 0, 0, 0)
	blackout.visible = false
	parent.add_child(blackout)

	# Liver toxic overlay - green tint with wobble feel
	var liver_overlay = ColorRect.new()
	liver_overlay.name = "LiverOverlay"
	liver_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	liver_overlay.color = Color(0.2, 0.8, 0.2, 0)
	parent.add_child(liver_overlay)

	# Pancreas crash overlay - orange/yellow pulse
	var pancreas_overlay = ColorRect.new()
	pancreas_overlay.name = "PancreasOverlay"
	pancreas_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pancreas_overlay.color = Color(1.0, 0.5, 0, 0)
	parent.add_child(pancreas_overlay)

	# Mouth overlay - red vignette for coughing/choking
	var mouth_overlay = ColorRect.new()
	mouth_overlay.name = "MouthOverlay"
	mouth_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	mouth_overlay.color = Color(0.8, 0, 0, 0)
	parent.add_child(mouth_overlay)

	# Eyes blur overlay - darkening/blur effect
	var eyes_overlay = ColorRect.new()
	eyes_overlay.name = "EyesOverlay"
	eyes_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	eyes_overlay.color = Color(0, 0, 0.05, 0)
	parent.add_child(eyes_overlay)

	# Legs overlay - darkening at edges for exhaustion
	var legs_overlay = ColorRect.new()
	legs_overlay.name = "LegsOverlay"
	legs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	legs_overlay.color = Color(0, 0, 0, 0)
	parent.add_child(legs_overlay)

	# Store references based on player
	if player_idx == 0:
		p1_blackout = blackout
		p1_liver_overlay = liver_overlay
		p1_pancreas_overlay = pancreas_overlay
		p1_mouth_overlay = mouth_overlay
		p1_eyes_overlay = eyes_overlay
		p1_legs_overlay = legs_overlay
	else:
		p2_blackout = blackout
		p2_liver_overlay = liver_overlay
		p2_pancreas_overlay = pancreas_overlay
		p2_mouth_overlay = mouth_overlay
		p2_eyes_overlay = eyes_overlay
		p2_legs_overlay = legs_overlay

func _process(delta: float) -> void:
	_effect_timer += delta
	_update_blackout()
	_update_organ_effects()

func _update_blackout() -> void:
	for player_idx in [0, 1]:
		var state = player_states[player_idx]
		if state["is_blackout"]:
			state["blackout_timer"] -= 0.016  # Approximate frame time
			# Pulse the blackout overlay
			var pulse = 0.9 + sin(_effect_timer * 3) * 0.05
			if player_idx == 0 and p1_blackout:
				p1_blackout.color = Color(0.05, 0, 0, pulse)
			elif player_idx == 1 and p2_blackout:
				p2_blackout.color = Color(0.05, 0, 0, pulse)
			if state["blackout_timer"] <= 0:
				clear_blackout(player_idx)

func _update_organ_effects() -> void:
	for player_idx in [0, 1]:
		var state = player_states[player_idx]

		# Get overlay references
		var liver_o = p1_liver_overlay if player_idx == 0 else p2_liver_overlay
		var pancreas_o = p1_pancreas_overlay if player_idx == 0 else p2_pancreas_overlay
		var mouth_o = p1_mouth_overlay if player_idx == 0 else p2_mouth_overlay
		var eyes_o = p1_eyes_overlay if player_idx == 0 else p2_eyes_overlay
		var legs_o = p1_legs_overlay if player_idx == 0 else p2_legs_overlay

		# Liver toxic effect - green pulsing based on toxin level
		if state["liver_toxic"] and liver_o:
			var toxin = state["liver_toxin_level"]
			var pulse = (sin(_effect_timer * 2) + 1) * 0.1  # Gentle pulse
			liver_o.color = Color(0.15, 0.5, 0.15, (toxin / 100.0) * 0.4 + pulse)
		elif liver_o:
			liver_o.color = Color(0.15, 0.5, 0.15, 0)

		# Pancreas crash - intense orange pulse
		if state["pancreas_crash"] and pancreas_o:
			var pumps = state["crash_pumps"]
			var required = state["crash_required"]
			var urgency = 1.0 - (pumps / float(required))
			var flash = (sin(_effect_timer * 8) + 1) * 0.3  # Fast flash when urgent
			pancreas_o.color = Color(1.0, 0.6, 0.0, 0.5 + flash * urgency)
		elif pancreas_o:
			pancreas_o.color = Color(1.0, 0.6, 0.0, 0)

		# Mouth coughing - red vignette that pulses
		if state["mouth_coughing"] and mouth_o:
			var cough_pulse = (sin(_effect_timer * 5) + 1) * 0.15
			mouth_o.color = Color(0.6, 0.1, 0.1, 0.3 + cough_pulse)
		elif state["mouth_choking"] and mouth_o:
			var choke_pulse = (sin(_effect_timer * 7) + 1) * 0.25
			mouth_o.color = Color(0.8, 0, 0, 0.5 + choke_pulse)
		elif mouth_o:
			mouth_o.color = Color(0.6, 0.1, 0.1, 0)

		# Eyes blur - darkening and desaturating effect
		if state["eyes_blur"] > 0 and eyes_o:
			var blur = state["eyes_blur"]
			var twitch_extra = 0.1 if state["eyes_twitching"] else 0.0
			eyes_o.color = Color(0, 0, 0.05, (blur / 100.0) * 0.85 + twitch_extra)
		elif eyes_o:
			eyes_o.color = Color(0, 0, 0.05, 0)

		# Legs exhaustion - darkening vignette at edges
		if state["legs_exhausted"] and legs_o:
			legs_o.color = Color(0, 0, 0, 0.3 + sin(_effect_timer * 2) * 0.1)
		elif state["legs_leg_drag"] and legs_o:
			legs_o.color = Color(0, 0, 0, 0.2 + sin(_effect_timer * 4) * 0.1)
		elif state["legs_crawling"] and legs_o:
			legs_o.color = Color(0, 0, 0, 0.15)
		elif legs_o:
			legs_o.color = Color(0, 0, 0, 0)

# ============ PUBLIC API FOR ORGANS ============

## HEART: Blackout when consciousness lost
func on_player_consciousness_lost(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["is_blackout"] = true
	player_states[player_idx]["blackout_timer"] = 10.0
	if player_idx == 0 and p1_blackout:
		p1_blackout.visible = true
		p1_blackout.color = Color(0.05, 0, 0, 0.95)
	elif player_idx == 1 and p2_blackout:
		p2_blackout.visible = true
		p2_blackout.color = Color(0.05, 0, 0, 0.95)
	_create_screen_flash(Color(0.5, 0, 0, 0.7), 0.3)

func on_player_consciousness_restored(player_idx: int) -> void:
	clear_blackout(player_idx)

func clear_blackout(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["is_blackout"] = false
	player_states[player_idx]["blackout_timer"] = 0.0
	if player_idx == 0 and p1_blackout:
		p1_blackout.visible = false
	elif player_idx == 1 and p2_blackout:
		p2_blackout.visible = false

func is_player_blackout(player_idx: int) -> bool:
	if player_idx < 0 or player_idx > 1:
		return false
	return player_states[player_idx]["is_blackout"]

## LIVER: Toxicity level changes
func on_liver_toxicity_changed(player_idx: int, toxin_level: float, is_intoxicated: bool) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["liver_toxin_level"] = toxin_level
	player_states[player_idx]["liver_toxic"] = is_intoxicated

func on_liver_drunk_activated(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["liver_toxic"] = true

func on_liver_drunk_deactivated(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["liver_toxic"] = false
	player_states[player_idx]["liver_toxin_level"] = 0.0

## PANCREAS: Sugar crash state
func on_pancreas_crash_started(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["pancreas_crash"] = true
	player_states[player_idx]["crash_pumps"] = 0

func on_pancreas_crash_pump(player_idx: int, pumps: int, required: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["crash_pumps"] = pumps
	player_states[player_idx]["crash_required"] = required

func on_pancreas_crash_recovered(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["pancreas_crash"] = false
	player_states[player_idx]["crash_pumps"] = 0

## MOUTH: Coughing and choking
func on_mouth_cough_started(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["mouth_coughing"] = true
	player_states[player_idx]["mouth_choking"] = false

func on_mouth_cough_ended(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["mouth_coughing"] = false

func on_mouth_choke_started(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["mouth_choking"] = true
	player_states[player_idx]["mouth_coughing"] = false

func on_mouth_choke_recovered(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["mouth_choking"] = false

func on_mouth_breath_changed(player_idx: int, breath_level: float) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["breath_level"] = breath_level

## EYES: Blur level changes
func on_eyes_blur_changed(player_idx: int, blur_level: float) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["eyes_blur"] = blur_level

func on_eyes_twitch_started(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["eyes_twitching"] = true

func on_eyes_twitch_ended(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["eyes_twitching"] = false

func clear_eyes_effects(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["eyes_blur"] = 0.0
	player_states[player_idx]["eyes_twitching"] = false

## ARMS: Tremor state
func on_arms_tremor_activated(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["arms_tremor"] = true

func on_arms_tremor_deactivated(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["arms_tremor"] = false

func on_arms_steadying_changed(player_idx: int, is_steadying: bool) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["arms_steadying"] = is_steadying

## LEGS: Crawling, exhaustion, leg drag
func on_legs_crawl_started(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["legs_crawling"] = true

func on_legs_crawl_ended(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["legs_crawling"] = false

func on_legs_exhaustion_started(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["legs_exhausted"] = true

func on_legs_exhaustion_ended(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["legs_exhausted"] = false

func on_legs_leg_drag_started(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["legs_leg_drag"] = true

func on_legs_leg_drag_ended(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx]["legs_leg_drag"] = false

## Clear all effects for a player
func clear_all_effects(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	player_states[player_idx] = {
		"is_blackout": false, "blackout_timer": 0.0,
		"liver_toxic": false, "liver_toxin_level": 0.0,
		"pancreas_crash": false, "crash_pumps": 0, "crash_required": 12,
		"mouth_coughing": false, "mouth_choking": false, "breath_level": 100.0,
		"eyes_blur": 0.0, "eyes_twitching": false,
		"arms_tremor": false, "arms_steadying": false,
		"legs_crawling": false, "legs_exhausted": false, "legs_leg_drag": false
	}
	# Reset all overlays for this player
	var blackout = p1_blackout if player_idx == 0 else p2_blackout
	var liver = p1_liver_overlay if player_idx == 0 else p2_liver_overlay
	var pancreas = p1_pancreas_overlay if player_idx == 0 else p2_pancreas_overlay
	var mouth = p1_mouth_overlay if player_idx == 0 else p2_mouth_overlay
	var eyes = p1_eyes_overlay if player_idx == 0 else p2_eyes_overlay
	var legs = p1_legs_overlay if player_idx == 0 else p2_legs_overlay

	if blackout: blackout.visible = false
	if liver: liver.color = Color(0.15, 0.5, 0.15, 0)
	if pancreas: pancreas.color = Color(1.0, 0.6, 0.0, 0)
	if mouth: mouth.color = Color(0.6, 0.1, 0.1, 0)
	if eyes: eyes.color = Color(0, 0, 0.05, 0)
	if legs: legs.color = Color(0, 0, 0, 0)

## Check if input should be blocked (during blackout)
func should_block_input(player_idx: int, action_name: String) -> bool:
	if not is_player_blackout(player_idx):
		return false
	# Only allow A button during blackout (for heart restart)
	var allowed_actions = ["p1_main_button", "p2_main_button", "game_main_button"]
	return action_name not in allowed_actions

## Get current status for debugging
func get_status() -> Dictionary:
	return {
		"p1_state": player_states[0],
		"p2_state": player_states[1],
		"initialized": _is_initialized
	}

func _create_screen_flash(color: Color, duration: float) -> void:
	var flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = color

	var root = get_tree().root
	if root:
		root.add_child(flash)

	# Fade out and auto-free without await to avoid coroutine issues
	var fade_tween = flash.create_tween()
	fade_tween.tween_property(flash, "modulate:a", 0.0, duration)
	fade_tween.tween_callback(flash.queue_free)
