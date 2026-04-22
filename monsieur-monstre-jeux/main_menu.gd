extends Control
var rand_game = 0

func _process(delta: float) -> void:
	if Input.is_joy_button_pressed(0, JOY_BUTTON_A) or Input.is_joy_button_pressed(1, JOY_BUTTON_A):
		rand_game = randi_range(0,10)
		if rand_game > 5:
			get_tree().change_scene_to_file("res://scenes/cam_template.tscn")
		else:
			get_tree().change_scene_to_file("res://manger/scene/manger_minigame.tscn")
