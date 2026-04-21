extends Control

# Main Menu for Monsieur Monstre
# Supports navigation with any connected controller

var _menu_controller_index: int = 0  # Which gamepad controls the menu
var _last_menu_action_time: Dictionary = {}  # Debounce tracking
const MENU_ACTION_DEBOUNCE: float = 0.15  # Seconds between menu actions

func _ready() -> void:
	# Connect to gamepad events for dynamic menu control
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	
	# Set initial focus to first button
	_set_initial_focus()

func _set_initial_focus() -> void:
	# Get the Start button and set focus
	var vbox = get_node_or_null("VBoxContainer")
	if vbox:
		var start_btn = vbox.get_node_or_null("StartButton")
		if start_btn:
			start_btn.grab_focus()

func _input(event: InputEvent) -> void:
	# Handle gamepad navigation for menu buttons
	_process_menu_input(event)

func _process_menu_input(event: InputEvent) -> void:
	# Only process joypad events
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	
	# Check for menu navigation actions
	var action = _get_menu_action(event)
	if action == "":
		return
	
	# Debounce menu actions
	var current_time = Time.get_ticks_msec() / 1000.0
	var last_time = _last_menu_action_time.get(action, 0.0)
	if current_time - last_time < MENU_ACTION_DEBOUNCE:
		return
	_last_menu_action_time[action] = current_time
	
	# Find current focused button
	var focused = get_focused_button()
	
	match action:
		"menu_up", "menu_left":
			_move_focus(focused, -1)
		"menu_down", "menu_right":
			_move_focus(focused, 1)
		"menu_accept":
			if focused and focused.has_method("emit_signal"):
				# Press the focused button
				_fake_button_press(focused)

func _get_menu_action(event: InputEvent) -> String:
	# Map joypad input to menu actions
	if event is InputEventJoypadButton:
		var button_index = event.get_button_index()
		# D-pad
		if button_index == 8:  # D-pad up
			return "menu_up"
		elif button_index == 9:  # D-pad down
			return "menu_down"
		elif button_index == 10:  # D-pad left
			return "menu_left"
		elif button_index == 11:  # D-pad right
			return "menu_right"
		elif button_index == 0:  # A button
			return "menu_accept"
		elif button_index == 1:  # B button
			return "menu_cancel"
	elif event is InputEventJoypadMotion:
		var axis = event.get_axis()
		var value = event.get_axis_value()
		if abs(value) > 0.5:
			if axis == 1:  # Left stick Y
				return "menu_down" if value > 0 else "menu_up"
			elif axis == 0:  # Left stick X
				return "menu_right" if value > 0 else "menu_left"
	return ""

func get_focused_button() -> Button:
	var vbox = get_node_or_null("VBoxContainer")
	if not vbox:
		return null
	
	var buttons = []
	for child in vbox.get_children():
		if child is Button:
			buttons.append(child)
	
	for btn in buttons:
		if btn.has_focus():
			return btn
	
	return buttons[0] if buttons.size() > 0 else null

func _move_focus(current: Button, direction: int) -> void:
	var vbox = get_node_or_null("VBoxContainer")
	if not vbox:
		return
	
	var buttons = []
	for child in vbox.get_children():
		if child is Button:
			buttons.append(child)
	
	if buttons.size() == 0:
		return
	
	var current_idx = -1
	if current:
		current_idx = buttons.find(current)
	
	var next_idx = current_idx + direction
	if next_idx < 0:
		next_idx = buttons.size() - 1
	elif next_idx >= buttons.size():
		next_idx = 0
	
	buttons[next_idx].grab_focus()

func _fake_button_press(button: Button) -> void:
	# Simulate button press for gamepad - emit the pressed signal
	button.emit_signal("pressed")

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	"""Update which gamepad controls the menu when controllers change."""
	if connected:
		# Use the first connected gamepad for menu control
		_menu_controller_index = device_id
	else:
		# Reassign to another connected gamepad if available
		var connected_joypads = Input.get_connected_joypads()
		if connected_joypads.size() > 0:
			_menu_controller_index = connected_joypads[0]
		else:
			_menu_controller_index = 0

func _process(_delta: float) -> void:
	# Handle menu navigation with any connected gamepad
	# This allows any gamepad to navigate the menu without requiring Player 1's controller
	pass

func _on_start_pressed() -> void:
	# Load player selection screen instead of directly loading game
	var player_select_scene = load("res://scenes/player_select.tscn")
	var player_select = player_select_scene.instantiate()
	add_child(player_select)
	
	# Connect signals to handle flow
	player_select.player_assignment_complete.connect(_on_player_selection_complete)
	player_select.back_to_menu.connect(_on_player_selection_back)

func _on_player_selection_complete() -> void:
	# Player selection finished and ready to start
	# Guard against null tree (e.g., if called after tree change)
	if get_tree():
		get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_player_selection_back() -> void:
	# Player selection cancelled, stay on main menu
	pass

func _on_settings_pressed() -> void:
	# Open the display settings menu as a modal
	var settings_scene = load("res://scenes/settings_menu.tscn")
	var settings = settings_scene.instantiate()
	add_child(settings)

func _on_credits_pressed() -> void:
	# Credits placeholder
	print("Credits pressed - placeholder")

func _on_exit_pressed() -> void:
	if get_tree():
		get_tree().quit()
