extends CharacterBody2D

@export var controls: Resource = null
@export var handler: String = "arm"

@export var speed = 200
@export var rotation_speed = 2

@onready var sprite_arm = $ArmSprite
@onready var sprite_foot = $FeetSprite

@onready var area_arm = $ArmSpoonDetectionArea
@onready var area_foot = $FootSpoonDetectionArea

@onready var col_arm = $ArmSpoonCollision
@onready var col_foot = $FeetSpoonCollision

var rotation_direction = 0

### DECIDE WHICH COLLISION TO USE
func set_mode():
	if handler == "arm":
		sprite_arm.visible = true
		area_arm.monitoring = true
		col_arm.set_deferred("disabled", false)
		
		sprite_foot.visible = false
		area_foot.monitoring = false
		col_foot.set_deferred("disabled", true)
	if handler == "foot":
		sprite_arm.visible = false
		area_arm.monitoring = false
		col_arm.set_deferred("disabled", true)
		
		sprite_foot.visible = true
		area_foot.monitoring = true
		col_foot.set_deferred("disabled", false)

### MOVEMENT FUNCTIONS
func get_input():
	rotation_direction = Input.get_axis(controls.move_up, controls.move_down)
	
	var horizontal = Input.get_axis(controls.move_left, controls.move_right)
	var vertical = Input.get_axis(controls.r1, controls.l1)
	# ici on peut inverser les inputs gauche droite par haut bas pour le cas des sans bras
	if handler == "arm":
		pass # default case
	if handler == "foot":
		rotation_direction = Input.get_axis(controls.move_down, controls.move_up)

	velocity = (transform.x * horizontal + transform.y * vertical *3)* speed

### PEA DETECTION
func _on_spoon_detection_area_body_entered(body: Node2D) -> void:
	# stop physics influence, else the spoon is gonna fall under the peas gravity
	if body.is_in_group("pea"):
		body.gravity_scale = 0
		body.linear_velocity = Vector2.ZERO
		
		body.set_collision_layer_value(1, false) # adjust layer index
		body.set_collision_mask_value(1, false)
	

func _on_spoon_detection_area_body_exited(body: Node2D) -> void:
	# same logic as entering the spoon
	if body.is_in_group("pea"):
		body.gravity_scale = 1
		body.set_collision_layer_value(1, true) # adjust layer index
		body.set_collision_mask_value(1, true)

### MAIN LOOP
func _ready() -> void:
	set_mode()

func _process(delta: float) -> void:
	get_input()
	rotation += rotation_direction * rotation_speed * delta
	move_and_slide()

func _physics_process(delta):
	get_input()
	rotation += rotation_direction * rotation_speed * delta
	move_and_slide()

	var screen_size = get_viewport_rect().size
	
	global_position.x = clamp(global_position.x, 0, screen_size.x)
	global_position.y = clamp(global_position.y, 0, screen_size.y)
