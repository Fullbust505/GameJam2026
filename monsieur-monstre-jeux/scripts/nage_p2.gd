extends Node2D

@export var player_index = 1;
var input_velocity = Vector2.ZERO;
var speed = 200;

func _ready():
	pass

func _physics_process(delta: float) -> void:
	
	if Input.is_joy_button_pressed(player_index, JOY_BUTTON_A) and Input.is_action_just_pressed("game_main_button"):
		input_velocity += Vector2.UP * speed
	
	input_velocity+=Vector2.DOWN*delta*$RigidBody2D.gravity_scale*300
	
	position+=input_velocity*delta
