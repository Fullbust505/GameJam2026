extends Node2D
var speed = 200
@export var player_index=0
@export var cut_positions = []
var input_velocity = Vector2.ZERO
@onready var timer = $"../mg_duration"
@onready var minigame = $".."
signal ready_p1
signal finish_p1
var missing_organ_offset = Vector2.ZERO

var cutmark = preload("res://scenes/cut_mark.tscn")

func _physics_process(delta: float) -> void:
	input_velocity = Vector2.ZERO
	
	if not minigame.gamestate["players"]["p1"]["organs"]["arms"]:
		missing_organ_offset = Vector2.RIGHT * missing_organ()

	if not minigame.gamestate["players"]["p1"]["organs"]["eyes"]:
		$"../blur_cam_p1".visible=true
	
	if not timer.is_stopped():
		if Input.is_joy_button_pressed(player_index, JOY_BUTTON_A) and Input.is_action_just_pressed("game_main_button") and cut_positions.size() < minigame.number_of_cuts-1 and minigame.timeouts==1:
			cut_positions.append(position.x)
			var new_cut = cutmark.instantiate()
			new_cut.position = position
			$SliceP1.play()
			print(cut_positions)
			minigame.add_child(new_cut)
		input_velocity += Input.get_joy_axis(player_index, JOY_AXIS_LEFT_X) * Vector2.RIGHT * 200
		input_velocity += missing_organ_offset
		
	if timer.is_stopped() and Input.is_joy_button_pressed(player_index, JOY_BUTTON_A):
		ready_p1.emit()
	
	if cut_positions.size() == minigame.number_of_cuts-1:
		finish_p1.emit()

	position += input_velocity * delta
	if position.x > 165:
		position -= input_velocity * delta
	elif position.x < -165:
		position -= input_velocity * delta

func missing_organ():
	return (100*sin(timer.time_left*5)+80*cos(timer.time_left*3))
