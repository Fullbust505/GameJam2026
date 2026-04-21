extends CharacterBody2D

@export var controls: Resource = null

@export var speed = 100
@export var rotation_speed = 2

@onready var sensor = $SpoonDetectionArea

var rotation_direction = 0

func _ready() -> void:
	pass

### MOVEMENT FUNCTIONS
func get_input():
	rotation_direction = Input.get_axis(controls.move_up, controls.move_down)
	var horizontal = Input.get_axis(controls.move_left, controls.move_right)
	var vertical = Input.get_axis(controls.r1, controls.l1)

	velocity = (transform.x * horizontal + transform.y * vertical *3)* speed
	# yes, we do not use transform.y as it is relative to the characters angular position

### PEA DETECTION
func _on_spoon_detection_area_body_entered(body: Node2D) -> void:
	# don't need to check if it's a pea, it can only be this
	# stop physics influence, else the spoon is gonna fall under the peas gravity
	body.gravity_scale = 0
	body.linear_velocity = Vector2.ZERO
	
	body.set_collision_layer_value(1, false) # adjust layer index
	body.set_collision_mask_value(1, false)
	

func _on_spoon_detection_area_body_exited(body: Node2D) -> void:
	# same logic as entering the spoon
	
	body.gravity_scale = 1
	body.set_collision_layer_value(1, true) # adjust layer index
	body.set_collision_mask_value(1, true)

### MAIN LOOP
func _process(delta: float) -> void:
	get_input()
	# ici on peut inverser les inputs gauche droite par haut bas pour le cas des sans bras
	rotation += rotation_direction * rotation_speed * delta
	move_and_slide()
