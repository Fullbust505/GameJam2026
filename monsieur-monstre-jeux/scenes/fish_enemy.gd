extends Node2D

var target_depth: float = 800.0
var current_depth: float = 0.0
var horizontal_position: float = 0.0
var speed: float = 100.0
var horizontal_speed: float = 80.0
var horizontal_direction: int = 1  # 1 = right, -1 = left
var hit_p1: bool = false
var hit_p2: bool = false
var lifetime: float = 0.0
var max_lifetime: float = 20.0
var start_x: float = 0.0
var x_range: float = 200.0

func spawn(spawn_depth: float, target: float, start_pos_x: float = 0.0) -> void:
	current_depth = spawn_depth
	target_depth = target
	start_x = start_pos_x
	horizontal_position = start_x
	position.y = current_depth
	position.x = horizontal_position

	# Start from left or right side randomly
	horizontal_direction = 1 if randf() > 0.5 else -1
	horizontal_speed = randf_range(60, 150)
	speed = randf_range(40, 80)  # Slow descent rate
	lifetime = 0.0
	hit_p1 = false
	hit_p2 = false
	x_range = randf_range(100, 250)

func update_position(delta: float) -> void:
	lifetime += delta

	# Move horizontally (oscillate side to side)
	horizontal_position += horizontal_direction * horizontal_speed * delta

	# Bounce off horizontal bounds
	if horizontal_position > start_x + x_range:
		horizontal_direction = -1
	elif horizontal_position < start_x - x_range:
		horizontal_direction = 1

	# Slowly descend toward target depth (only go down, never up)
	if current_depth < target_depth:
		current_depth += speed * delta

	position.x = horizontal_position
	position.y = current_depth

	# Remove if lifetime exceeded or reached target
	if lifetime > max_lifetime or current_depth >= target_depth:
		queue_free()
