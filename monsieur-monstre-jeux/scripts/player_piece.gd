class_name PlayerPiece
extends Node2D

@export var player_index: int = 0

var target_position: Vector2
var speed: float = 400.0

func _physics_process(delta: float):
	if position.distance_to(target_position) > 5:
		position = position.move_toward(target_position, speed * delta)
	else:
		position = target_position

func move_to(new_position: Vector2):
	target_position = new_position

func _ready():
	target_position = position
