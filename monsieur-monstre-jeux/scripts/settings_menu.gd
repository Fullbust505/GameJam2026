extends Control

var focused_idx: int = 0
var buttons: Array = []
var move_cooldown: float = 0
var last_dir: int = 0

func _ready():
	var vbox = $TabContainer/DisplayTab/VBox
	buttons = []
	for child in vbox.get_children():
		if child is Button:
			buttons.append(child)

	var input_grid = $TabContainer/InputTab/P1Grid
	if input_grid:
		for child in input_grid.get_children():
			if child is Button:
				buttons.append(child)

	var input_grid2 = $TabContainer/InputTab/P2Grid
	if input_grid2:
		for child in input_grid2.get_children():
			if child is Button:
				buttons.append(child)

	if buttons.size() > 0:
		focused_idx = 0
		buttons[0].grab_focus()

func _physics_process(delta: float):
	if move_cooldown > 0:
		move_cooldown -= delta
		return

	var axis_y = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	var dpad_up = Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP)
	var dpad_down = Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN)

	if dpad_up or axis_y < -0.5:
		if last_dir != -1:
			focused_idx = (focused_idx - 1 + buttons.size()) % buttons.size()
			buttons[focused_idx].grab_focus()
			move_cooldown = 0.2
			last_dir = -1
	elif dpad_down or axis_y > 0.5:
		if last_dir != 1:
			focused_idx = (focused_idx + 1) % buttons.size()
			buttons[focused_idx].grab_focus()
			move_cooldown = 0.2
			last_dir = 1
	else:
		last_dir = 0

	if Input.is_joy_button_pressed(0, JOY_BUTTON_A):
		buttons[focused_idx].emit_signal("pressed")
	elif Input.is_joy_button_pressed(0, JOY_BUTTON_B):
		go_back()
	elif Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER):
		$TabContainer.current_tab = 0
	elif Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER):
		$TabContainer.current_tab = 1

func _on_back_pressed():
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_reset_defaults_pressed():
	print("Reset defaults pressed")

func go_back():
	get_tree().change_scene_to_file("res://main_menu.tscn")
