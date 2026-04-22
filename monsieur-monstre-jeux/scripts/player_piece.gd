class_name PlayerPiece
extends Node2D

@export var player_index: int = 0

var target_position: Vector2 = Vector2.ZERO
var speed: float = 600.0
var initialized := false

func _process(delta: float):
	if not initialized:
		target_position = position
		initialized = true
		return

	var dist = position.distance_to(target_position)
	if dist > 2:
		position = position.move_toward(target_position, speed * delta)
	else:
		position = target_position

func move_to(new_position: Vector2):
	target_position = new_position

func _ready():
	target_position = position
