extends CharacterBody2D

@export var controls: Resource = null

@export var speed = 100
@export var rotation_speed = 2

var rotation_direction = 0

func _ready() -> void:
	pass

func get_input():
	rotation_direction = Input.get_axis(controls.move_left, controls.move_right)
	velocity = transform.x * Input.get_axis(controls.move_down, controls.move_up) * speed
	
func _process(delta: float) -> void:
	get_input()
	rotation += rotation_direction * rotation_speed * delta
	move_and_slide()
