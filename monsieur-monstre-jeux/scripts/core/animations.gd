extends Node
class_name Animations

## Animations Helper for Monsieur Monstre
## Provides reusable animation methods and sound effect triggers
## Can be used by all game systems for consistent polish

# Singleton instance for easy access
static func get_instance() -> Animations:
	var node = Engine.get_main_loop().root.get_node_or_null("/root/Animations")
	return node as Animations

# SFX AudioStreamPlayer references
var _sfx_players: Array = []
var _current_sfx_volume: float = 0.0

# Screen flash overlay reference
var _screen_flash: ColorRect = null
var _screen_shake_target: Node = null
var _shake_offset: Vector2 = Vector2.ZERO

# Particle burst scene reference
const PARTICLE_BURST_SCENE: String = "res://scenes/particle_burst.tscn"

func _ready() -> void:
	# Pre-load SFX files for quick playback
	_setup_sfx_players()
	
	# Create screen flash overlay
	_create_screen_flash()
	
	# Set as autoload singleton
	process_mode = Node.PROCESS_MODE_ALWAYS

func _setup_sfx_players() -> void:
	# Create multiple audio players for overlapping sounds
	for i in range(3):
		var player = AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		player.volume_db = -10.0  # Start with reasonable volume
		add_child(player)
		_sfx_players.append(player)

func _create_screen_flash() -> void:
	var viewport = get_tree().root
	_screen_flash = ColorRect.new()
	_screen_flash.name = "ScreenFlash"
	_screen_flash.color = Color.WHITE
	_screen_flash.z_index = 1000
	_screen_flash.visible = false
	_screen_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_flash.offset_left = 0
	_screen_flash.offset_top = 0
	_screen_flash.offset_right = 0
	_screen_flash.offset_bottom = 0
	viewport.add_child(_screen_flash)

# ==================== FADE ANIMATIONS ====================

## Fade in a control (make visible with alpha animation)
func fade_in(target: Control, duration: float = 0.3, delay: float = 0.0) -> void:
	if not target:
		return
	
	var tween = target.create_tween()
	if delay > 0:
		tween.tween_interval(delay)
	
	target.modulate.a = 0.0
	target.visible = true
	
	tween.tween_property(target, "modulate:a", 1.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

## Fade out a control (hide with alpha animation)
func fade_out(target: Control, duration: float = 0.3, delay: float = 0.0, hide_after: bool = true) -> void:
	if not target:
		return
	
	var tween = target.create_tween()
	if delay > 0:
		tween.tween_interval(delay)
	
	tween.tween_property(target, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	
	if hide_after:
		tween.tween_callback(func(): target.visible = false)

## Quick fade in (convenience method)
func quick_fade_in(target: Control) -> void:
	fade_in(target, 0.2)

## Quick fade out (convenience method)
func quick_fade_out(target: Control) -> void:
	fade_out(target, 0.2)

# ==================== SLIDE ANIMATIONS ====================

## Slide in from left
func slide_in_left(target: Control, duration: float = 0.4, delay: float = 0.0) -> void:
	if not target:
		return
	
	var tween = target.create_tween()
	if delay > 0:
		tween.tween_interval(delay)
	
	target.position.x = -target.size.x
	target.visible = true
	
	tween.tween_property(target, "position:x", 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

## Slide in from right
func slide_in_right(target: Control, container_width: float, duration: float = 0.4, delay: float = 0.0) -> void:
	if not target:
		return
	
	var tween = target.create_tween()
	if delay > 0:
		tween.tween_interval(delay)
	
	target.position.x = container_width
	target.visible = true
	
	tween.tween_property(target, "position:x", container_width - target.size.x, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

## Slide in from top
func slide_in_top(target: Control, duration: float = 0.4, delay: float = 0.0) -> void:
	if not target:
		return
	
	var tween = target.create_tween()
	if delay > 0:
		tween.tween_interval(delay)
	
	target.position.y = -target.size.y
	target.visible = true
	
	tween.tween_property(target, "position:y", 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

## Slide in from bottom
func slide_in_bottom(target: Control, container_height: float, duration: float = 0.4, delay: float = 0.0) -> void:
	if not target:
		return
	
	var tween = target.create_tween()
	if delay > 0:
		tween.tween_interval(delay)
	
	target.position.y = container_height
	target.visible = true
	
	tween.tween_property(target, "position:y", container_height - target.size.y, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

## Slide out to left
func slide_out_left(target: Control, duration: float = 0.3, hide_after: bool = true) -> void:
	if not target:
		return
	
	var tween = target.create_tween()
	tween.tween_property(target, "position:x", -target.size.x, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	
	if hide_after:
		tween.tween_callback(func(): target.visible = false)

## Slide out to right
func slide_out_right(target: Control, container_width: float, duration: float = 0.3, hide_after: bool = true) -> void:
	if not target:
		return
	
	var tween = target.create_tween()
	tween.tween_property(target, "position:x", container_width, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	
	if hide_after:
		tween.tween_callback(func(): target.visible = false)

## Slide out to top
func slide_out_top(target: Control, duration: float = 0.3, hide_after: bool = true) -> void:
	if not target:
		return
	
	var tween = target.create_tween()
	tween.tween_property(target, "position:y", -target.size.y, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	
	if hide_after:
		tween.tween_callback(func(): target.visible = false)

## Slide out to bottom
func slide_out_bottom(target: Control, container_height: float, duration: float = 0.3, hide_after: bool = true) -> void:
	if not target:
		return
	
	var tween = target.create_tween()
	tween.tween_property(target, "position:y", container_height, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	
	if hide_after:
		tween.tween_callback(func(): target.visible = false)

# ==================== SHAKE ANIMATIONS ====================

## Shake effect on a node
func shake(target: Node, intensity: float = 10.0, duration: float = 0.3, frequency: float = 30.0) -> void:
	if not target:
		return
	
	var tween = target.create_tween()
	var elapsed = 0.0
	var original_pos = target.position
	
	while elapsed < duration:
		var offset_x = randf_range(-intensity, intensity) * (1.0 - elapsed / duration)
		var offset_y = randf_range(-intensity, intensity) * (1.0 - elapsed / duration)
		target.position = original_pos + Vector2(offset_x, offset_y)
		elapsed += 1.0 / frequency
		tween.tween_interval(1.0 / frequency)
	
	target.position = original_pos  # Reset to original position

## Screen shake effect (shakes the camera/viewport)
func screen_shake(intensity: float = 10.0, duration: float = 0.3, frequency: float = 30.0) -> void:
	var viewport = get_tree().root
	_screen_shake_target = viewport
	
	var tween = viewport.create_tween()
	var elapsed = 0.0
	var original_offset = _shake_offset
	
	while elapsed < duration:
		var offset_x = randf_range(-intensity, intensity) * (1.0 - elapsed / duration)
		var offset_y = randf_range(-intensity, intensity) * (1.0 - elapsed / duration)
		_shake_offset = Vector2(offset_x, offset_y)
		viewport.canvas_transform.origin = _shake_offset
		elapsed += 1.0 / frequency
		tween.tween_interval(1.0 / frequency)
	
	_shake_offset = original_offset
	viewport.canvas_transform.origin = Vector2.ZERO

## Subtle shake for penalties
func penalty_shake(target: Node) -> void:
	shake(target, 8.0, 0.25)

## Stronger shake for critical events
func critical_shake(target: Node) -> void:
	shake(target, 15.0, 0.4)

# ==================== BOUNCE ANIMATIONS ====================

## Bounce animation
func bounce(target: Control, scale_amount: float = 1.2, duration: float = 0.3) -> void:
	if not target:
		return
	
	var tween = target.create_tween()
	var original_scale = target.scale
	
	tween.tween_property(target, "scale", original_scale * scale_amount, duration * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(target, "scale", original_scale, duration * 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)

## Bounce in animation (scale from 0)
func bounce_in(target: Control, duration: float = 0.4) -> void:
	if not target:
		return
	
	var tween = target.create_tween()
	target.scale = Vector2.ZERO
	target.visible = true
	
	tween.tween_property(target, "scale", Vector2.ONE, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## Bounce out animation (scale to 0)
func bounce_out(target: Control, duration: float = 0.3) -> void:
	if not target:
		return
	
	var tween = target.create_tween()
	tween.tween_property(target, "scale", Vector2.ZERO, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func(): target.visible = false)

## Pulse animation (continuous subtle scale)
func pulse(target: Control, scale_amount: float = 1.1, duration: float = 0.5) -> void:
	if not target:
		return
	
	var tween = target.create_tween().set_loops()
	var original_scale = target.scale
	
	tween.tween_property(target, "scale", original_scale * scale_amount, duration * 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(target, "scale", original_scale, duration * 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

## Organ icon bounce for HUD
func organ_bounce(target: Control) -> void:
	bounce(target, 1.3, 0.35)

# ==================== SCREEN FLASH ====================

## Flash screen with color (for organ gain/loss)
func screen_flash(color: Color = Color.WHITE, duration: float = 0.15) -> void:
	if not _screen_flash:
		return
	
	_screen_flash.color = color
	_screen_flash.visible = true
	_screen_flash.modulate.a = 0.6
	
	var tween = _screen_flash.create_tween()
	tween.tween_property(_screen_flash, "modulate:a", 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func(): _screen_flash.visible = false)

## Green flash for organ gain
func organ_gain_flash() -> void:
	screen_flash(Color(0.2, 0.8, 0.2), 0.2)

## Red flash for organ loss
func organ_loss_flash() -> void:
	screen_flash(Color(0.8, 0.2, 0.2), 0.2)

## Gold flash for bonus/money gain
func bonus_flash() -> void:
	screen_flash(Color(0.9, 0.8, 0.2), 0.25)

## White flash for neutral events
func neutral_flash() -> void:
	screen_flash(Color.WHITE, 0.1)

# ==================== TILE ANIMATIONS ====================

## Tile pulse highlight
func tile_pulse(target: Control, duration: float = 1.0) -> void:
	if not target:
		return
	
	var tween = target.create_tween().set_loops()
	var original_scale = target.scale
	
	tween.tween_property(target, "scale", original_scale * 1.05, duration * 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(target, "scale", original_scale, duration * 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

## Tile glow effect
func tile_glow(target: Control, color: Color, duration: float = 0.3) -> void:
	if not target:
		return

	var tween = target.create_tween()
	var bg = target.get_node_or_null("Border")
	if bg:
		tween.tween_property(bg, "color", color, duration)
	else:
		# Add a border overlay if not present
		var border = ColorRect.new()
		border.name = "Border"
		border.color = color
		border.set_anchors_preset(Control.PRESET_FULL_RECT)
		border.z_index = -1
		target.add_child(border)
		tween.tween_property(border, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)

# ==================== PLAYER TOKEN ANIMATIONS ====================

## Animate player token movement
func animate_token_move(token: Control, from_pos: Vector2, to_pos: Vector2, duration: float = 0.5) -> void:
	if not token:
		return
	
	token.position = from_pos
	
	var tween = token.create_tween()
	tween.tween_property(token, "position", to_pos, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

## Token bounce on landing
func token_land_bounce(token: Control) -> void:
	bounce(token, 1.15, 0.3)

## Token spin animation
func token_spin(token: Control, duration: float = 0.5) -> void:
	if not token:
		return
	
	var tween = token.create_tween()
	tween.tween_property(token, "rotation", TAU, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)

# ==================== BOARD ENTRANCE ====================

## Staggered board entrance animation
func board_entrance(tiles: Array, duration_per_tile: float = 0.1) -> void:
	var delay = 0.0
	for tile in tiles:
		if is_instance_valid(tile):
			tile.scale = Vector2.ZERO
			tile.visible = true
			
			var tween = tile.create_tween()
			tween.tween_interval(delay)
			tween.tween_property(tile, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			
			delay += duration_per_tile

## Fade in entire board
func board_fade_in(board: Control, duration: float = 0.5) -> void:
	if not board:
		return
	
	board.modulate.a = 0.0
	board.visible = true
	
	var tween = board.create_tween()
	tween.tween_property(board, "modulate:a", 1.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

# ==================== NUMBER/STAT ANIMATIONS ====================

## Animate number change (tick up/down effect)
func animate_number_change(label: Label, from_value: int, to_value: int, duration: float = 0.5) -> void:
	if not label:
		return
	
	var tween = label.create_tween()
	var steps = max(1, int(duration * 30))  # 30 updates per second
	var step_value = (to_value - from_value) / float(steps)
	
	label.text = str(from_value)
	
	var current_value = from_value
	for i in range(steps):
		current_value += step_value
		if i == steps - 1:
			current_value = to_value  # Ensure exact final value
		label.text = str(int(current_value))
		tween.tween_interval(duration / float(steps))

## Money tick animation
func money_tick(label: Label, from_value: int, to_value: int) -> void:
	animate_number_change(label, from_value, to_value, 0.4)
	# Optional: add color flash
	if to_value > from_value:
		bonus_flash()
	else:
		neutral_flash()

## Score tick animation
func score_tick(label: Label, from_value: int, to_value: int) -> void:
	animate_number_change(label, from_value, to_value, 0.3)

# ==================== MINIGAME POLISH ====================

## Countdown animation (3, 2, 1, GO!)
func countdown_3_2_1_go(countdown_label: Label, callback: Callable, duration: float = 1.0) -> void:
	if not countdown_label:
		callback.call()
		return
	
	var sequence = ["3", "2", "1", "GO!"]
	var colors = [
		Color(0.8, 0.2, 0.2),  # Red for 3
		Color(0.8, 0.5, 0.1),  # Orange for 2
		Color(0.9, 0.7, 0.2),  # Yellow for 1
		Color(0.2, 0.8, 0.2)   # Green for GO!
	]
	
	var tween = countdown_label.create_tween()
	countdown_label.visible = true
	countdown_label.scale = Vector2.ZERO
	
	for i in range(sequence.size()):
		countdown_label.text = sequence[i]
		countdown_label.add_theme_color_override("default_color", colors[i])
		
		tween.tween_property(countdown_label, "scale", Vector2.ONE * 1.2, duration * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(countdown_label, "scale", Vector2.ONE, duration * 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
		
		if i < sequence.size() - 1:
			tween.tween_interval(duration * 0.3)
	
	tween.tween_interval(0.2)
	tween.tween_callback(func():
		countdown_label.visible = false
		callback.call()
	)

## Win text animation
func win_text(text_label: Label, duration: float = 2.0) -> void:
	if not text_label:
		return
	
	var tween = text_label.create_tween()
	text_label.visible = true
	text_label.text = "WIN!"
	text_label.add_theme_color_override("default_color", Color(0.2, 0.8, 0.2))
	
	text_label.scale = Vector2.ZERO
	tween.tween_property(text_label, "scale", Vector2.ONE * 1.5, duration * 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(text_label, "scale", Vector2.ONE, duration * 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(duration * 0.5)
	tween.tween_property(text_label, "modulate:a", 0.0, duration * 0.2)

## Lose text animation
func lose_text(text_label: Label, duration: float = 2.0) -> void:
	if not text_label:
		return
	
	var tween = text_label.create_tween()
	text_label.visible = true
	text_label.text = "LOSE"
	text_label.add_theme_color_override("default_color", Color(0.8, 0.2, 0.2))
	
	text_label.scale = Vector2.ZERO
	tween.tween_property(text_label, "scale", Vector2.ONE * 1.5, duration * 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(text_label, "scale", Vector2.ONE, duration * 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(duration * 0.5)
	tween.tween_property(text_label, "modulate:a", 0.0, duration * 0.2)

## Timer urgent animation (red pulsing)
func timer_urgent(timer_label: Label) -> void:
	if not timer_label:
		return
	
	pulse_urgent(timer_label, 0.5)
	timer_label.add_theme_color_override("default_color", Color(0.9, 0.2, 0.2))

## Pulse urgent (faster pulse for time running out)
func pulse_urgent(target: Control, duration: float = 0.3) -> void:
	if not target:
		return
	
	var tween = target.create_tween().set_loops(6)  # Stop after ~1.8 seconds
	var original_scale = target.scale
	
	tween.tween_property(target, "scale", original_scale * 1.15, duration * 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(target, "scale", original_scale, duration * 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

# ==================== PARTICLE EFFECTS ====================

## Create particle burst at position
func particle_burst(position: Vector2, particle_scene: String = "") -> void:
	var scene_path = particle_scene if particle_scene != "" else PARTICLE_BURST_SCENE
	
	if ResourceLoader.exists(scene_path):
		var packed_scene = load(scene_path)
		if packed_scene:
			var instance = packed_scene.instantiate()
			instance.global_position = position
			get_tree().root.add_child(instance)
			
			# Auto-cleanup after animation
			var timer = Timer.new()
			timer.wait_time = 2.0
			timer.one_shot = true
			timer.timeout.connect(func(): instance.queue_free())
			add_child(timer)
			timer.start()
	else:
		# Fallback: simple scale burst if no particle scene
		var burst_node = Node2D.new()
		burst_node.global_position = position
		burst_node.scale = Vector2.ZERO
		get_tree().root.add_child(burst_node)
		
		var tween = burst_node.create_tween()
		tween.tween_property(burst_node, "scale", Vector2.ONE * 3.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(burst_node, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): burst_node.queue_free())

## Organ gain particle effect
func organ_gain_particles(position: Vector2) -> void:
	particle_burst(position)

## Bonus activation particles
func bonus_particles(position: Vector2) -> void:
	particle_burst(position)

# ==================== SOUND EFFECT HELPERS ====================

## Play sound effect
func play_sfx(sfx_name: String, volume_db: float = -10.0) -> void:
	var path = "res://assets/sfx/" + sfx_name
	if not ResourceLoader.exists(path):
		return
	
	var stream = load(path)
	if not stream:
		return
	
	# Find an available player
	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.play()
			return

## Play bubble sound (for organ gain)
func play_bubble() -> void:
	play_sfx("bubble.mp3", -15.0)

## Play ambience (for ambience)
func play_ambience() -> void:
	play_sfx("ambience.mp3", -20.0)

## Stop all SFX
func stop_all_sfx() -> void:
	for player in _sfx_players:
		player.stop()

# ==================== COMBINED EFFECTS ====================

## Organ gain effect (flash + particles + sound)
func organ_gain_effect(position: Vector2) -> void:
	organ_gain_flash()
	organ_gain_particles(position)
	play_bubble()

## Organ loss effect (flash + shake)
func organ_loss_effect(target: Node) -> void:
	organ_loss_flash()
	penalty_shake(target)

## Bonus activation effect
func bonus_activation_effect(position: Vector2) -> void:
	bonus_flash()
	bonus_particles(position)

## Tile landing effect
func tile_landing_effect(tile: Control) -> void:
	if tile:
		bounce(tile, 1.1, 0.2)

## Challenge start effect
func challenge_start_effect() -> void:
	neutral_flash()
