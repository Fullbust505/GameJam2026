extends Node2D

## Air bubble for Apnea Survival minigame.
## Floats upward, can be collected by players for air restoration.

# Movement
var speed: float = 50.0  # Pixels per second upward
var wobble_amount: float = 20.0
var wobble_speed: float = 2.0
var time_elapsed: float = 0.0

# Boundaries
var surface_y: float = 80.0
var level_bottom: float = 600.0

# State
var is_collected: bool = false

# Visual components
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Create a simple bubble visual if sprite doesn't exist
	if not has_node("Sprite2D"):
		var new_sprite = Sprite2D.new()
		new_sprite.name = "Sprite2D"
		add_child(new_sprite)
	
	# Generate a procedural bubble texture
	_create_bubble_texture()

func _process(delta: float) -> void:
	if is_collected:
		return
	
	time_elapsed += delta
	
	# Float upward
	position.y -= speed * delta
	
	# Wobble horizontally
	var wobble = sin(time_elapsed * wobble_speed) * wobble_amount
	position.x += wobble * delta
	
	# Check if reached surface - queue free
	if position.y <= surface_y:
		queue_free()

func set_spawn_position(x: float, y: float, surface: float, bottom: float) -> void:
	position = Vector2(x, y)
	surface_y = surface
	level_bottom = bottom

func collect() -> void:
	is_collected = true
	queue_free()

func get_bounds() -> Vector2:
	return Vector2(15, 15)  # Approximate collision size

func _create_bubble_texture() -> void:
	# Create a simple circular texture for the bubble
	var size = 32
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	# Draw a simple circle with transparency
	for y in range(size):
		for x in range(size):
			var dx = x - size / 2
			var dy = y - size / 2
			var dist = sqrt(dx * dx + dy * dy)
			
			if dist < size / 2 - 2:
				# Inside bubble - light blue with transparency gradient
				var alpha = int(200 * (1.0 - dist / (size / 2)))
				var r = 150 + int(50 * (1.0 - dist / (size / 2)))
				var g = 200 + int(50 * (1.0 - dist / (size / 2)))
				var b = 255
				image.set_pixel(x, y, Color(r / 255.0, g / 255.0, b / 255.0, alpha / 255.0))
			elif dist < size / 2:
				# Bubble edge
				var alpha = int(100 * (1.0 - (dist - (size / 2 - 2)) / 2))
				image.set_pixel(x, y, Color(0.5, 0.8, 1.0, alpha / 255.0))
	
	var texture = ImageTexture.create_from_image(image)
	if sprite:
		sprite.texture = texture