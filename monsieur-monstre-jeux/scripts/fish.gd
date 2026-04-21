extends Node2D

## Fish hazard script for Apnea Survival minigame.
## Simple patrol AI - horizontal movement, bouncing off walls.

# Movement properties (set by level controller)
var speed: float = 100.0
var direction: int = 1  # 1 = right, -1 = left

# Level bounds
var level_width: float = 640.0
var surface_y: float = 80.0
var level_bottom: float = 600.0

# Animation
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Visual feedback
var flash_timer: float = 0.0
const FLASH_DURATION: float = 0.2

func _ready() -> void:
	# Set facing direction based on initial direction
	if direction < 0:
		animated_sprite.flip_h = true
	
	# Play animation if available
	if animated_sprite and animated_sprite.sprite_frames:
		animated_sprite.play()

func _physics_process(delta: float) -> void:
	# Horizontal patrol movement
	position.x += speed * direction * delta
	
	# Bounce off walls
	if position.x <= 30:
		direction = 1
		animated_sprite.flip_h = false
	elif position.x >= level_width - 30:
		direction = -1
		animated_sprite.flip_h = true
	
	# Slight vertical drift
	var time_ms = Time.get_ticks_msec()
	position.y += sin(time_ms * 0.002) * 10 * delta
	
	# Keep within vertical bounds
	position.y = clamp(position.y, surface_y + 20, level_bottom - 20)
	
	# Update flash effect
	if flash_timer > 0:
		flash_timer -= delta
		modulate = Color(1.5, 1.5, 1.5, 1.0)
	else:
		modulate = Color(1.0, 1.0, 1.0, 1.0)

func get_bounds() -> Vector2:
	# Return approximate collision size
	return Vector2(60, 35)

func on_player_collision() -> void:
	# Flash effect when hitting player
	flash_timer = FLASH_DURATION

func get_speed() -> float:
	return speed

func set_speed(new_speed: float) -> void:
	speed = new_speed

func get_direction() -> int:
	return direction

func set_direction(new_direction: int) -> void:
	direction = new_direction