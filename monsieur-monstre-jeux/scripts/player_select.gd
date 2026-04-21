extends Control

# Player Selection Screen for Monsieur Monstre
# Allows players to assign controllers before starting a game
# Supports dynamic controller detection and 1-4 players

signal player_assignment_complete()
signal back_to_menu()

const INPUT_SETTINGS_PATH := "res://scripts/core/input_settings.gd"

# Player slot constants (matching InputSettings)
const PLAYER1_SLOT := 0
const PLAYER2_SLOT := 1
const PLAYER3_SLOT := 2
const PLAYER4_SLOT := 3

# UI References
@onready var player1_panel: Panel = $PlayerSlots/Player1Panel
@onready var player2_panel: Panel = $PlayerSlots/Player2Panel
@onready var player1_name_label: Label = $PlayerSlots/Player1Panel/VBox/PlayerNameLabel
@onready var player1_status_label: Label = $PlayerSlots/Player1Panel/VBox/StatusLabel
@onready var player1_press_hint: Label = $PlayerSlots/Player1Panel/VBox/PressHintLabel
@onready var player2_name_label: Label = $PlayerSlots/Player2Panel/VBox/PlayerNameLabel
@onready var player2_status_label: Label = $PlayerSlots/Player2Panel/VBox/StatusLabel
@onready var player2_press_hint: Label = $PlayerSlots/Player2Panel/VBox/PressHintLabel
@onready var gamepad_list_panel: Panel = $GamepadListPanel
@onready var gamepad_list_container: VBoxContainer = $GamepadListPanel/VBox/GamepadListContainer
@onready var start_button: Button = $Buttons/StartButton
@onready var back_button: Button = $Buttons/BackButton
@onready var title_label: Label = $TitleLabel

# Optional debug mode UI
@onready var debug_mode_label: Label = $DebugModeLabel

var input_settings: Node = null
var debug_settings: Node = null
var selected_slot: int = -1  # Which player slot is being manually reassigned

# Gamepad navigation
var _last_menu_action_time: Dictionary = {}
const MENU_ACTION_DEBOUNCE: float = 0.15

func _ready() -> void:
	# Get InputSettings autoload
	input_settings = get_node("/root/InputSettings")
	
	# Get DebugSettings if available
	debug_settings = get_node_or_null("/root/DebugSettings")
	
	# Connect to InputSettings signals
	if input_settings.has_signal("gamepad_connected"):
		input_settings.gamepad_connected.connect(_on_gamepad_connected)
	if input_settings.has_signal("gamepad_disconnected"):
		input_settings.gamepad_disconnected.connect(_on_gamepad_disconnected)
	if input_settings.has_signal("controller_assignment_changed"):
		input_settings.controller_assignment_changed.connect(_on_controller_assignment_changed)
	
	# Connect UI signals
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	player1_panel.gui_input.connect(_on_player1_panel_input)
	player2_panel.gui_input.connect(_on_player2_panel_input)
	
	# Update debug mode visibility
	_update_debug_visibility()
	
	# Initial UI update
	_update_ui()
	
	# Set initial focus
	start_button.grab_focus()

func _input(event: InputEvent) -> void:
	# Handle gamepad navigation
	_process_gamepad_input(event)

func _process_gamepad_input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	
	# Don't process if gamepad list is open - let user navigate that
	if gamepad_list_panel.visible:
		return
	
	var action = _get_menu_action(event)
	if action == "":
		return
	
	# Debounce
	var current_time = Time.get_ticks_msec() / 1000.0
	var last_time = _last_menu_action_time.get(action, 0.0)
	if current_time - last_time < MENU_ACTION_DEBOUNCE:
		return
	_last_menu_action_time[action] = current_time
	
	var focused = get_focused_button()
	
	match action:
		"menu_up", "menu_left":
			_move_focus(focused, -1)
		"menu_down", "menu_right":
			_move_focus(focused, 1)
		"menu_accept":
			if focused:
				focused.emit_signal("pressed")

func _get_menu_action(event: InputEvent) -> String:
	if event is InputEventJoypadButton:
		var button_index = event.get_button_index()
		if button_index == 8:
			return "menu_up"
		elif button_index == 9:
			return "menu_down"
		elif button_index == 10:
			return "menu_left"
		elif button_index == 11:
			return "menu_right"
		elif button_index == 0:
			return "menu_accept"
		elif button_index == 1:
			return "menu_cancel"
	elif event is InputEventJoypadMotion:
		var axis = event.get_axis()
		var value = event.get_axis_value()
		if abs(value) > 0.5:
			if axis == 1:
				return "menu_down" if value > 0 else "menu_up"
			elif axis == 0:
				return "menu_right" if value > 0 else "menu_left"
	return ""

func get_focused_button() -> Button:
	var buttons = [back_button, start_button]
	for btn in buttons:
		if btn.has_focus():
			return btn
	return start_button

func _move_focus(current: Button, direction: int) -> void:
	var buttons = [back_button, start_button]
	if buttons.size() == 0:
		return
	
	var current_idx = buttons.find(current) if current else 0
	var next_idx = current_idx + direction
	if next_idx < 0:
		next_idx = buttons.size() - 1
	elif next_idx >= buttons.size():
		next_idx = 0
	
	buttons[next_idx].grab_focus()

func _update_debug_visibility() -> void:
	"""Show/hide debug mode label based on settings."""
	if debug_mode_label:
		var show_debug = debug_settings and (debug_settings.debug_mode or debug_settings.is_debug_build())
		debug_mode_label.visible = show_debug

func _process(_delta: float) -> void:
	# Check for any button press on unassigned gamepads
	_check_for_unassigned_gamepad_input()

func _check_for_unassigned_gamepad_input() -> void:
	"""Check if any button is pressed on an unassigned gamepad and auto-assign it."""
	var connected_joypads = Input.get_connected_joypads()
	
	for device_id in connected_joypads:
		# Check if this gamepad is already assigned
		if not _is_device_assigned(device_id):
			# Check for any button press on this gamepad
			if _has_gamepad_any_input(device_id):
				# Auto-assign to first available slot
				_assign_to_available_slot(device_id)

func _is_device_assigned(device_id: int) -> bool:
	"""Check if a device_id is already assigned to a player slot."""
	var gamepads = input_settings.get_gamepads()
	for slot in gamepads.values():
		if slot == device_id:
			return true
	return false

func _has_gamepad_any_input(device_id: int) -> bool:
	"""Check if the gamepad has any button or axis input."""
	# Check all buttons
	for button_index in range(16):  # Common button range
		if Input.is_joy_button_pressed(device_id, button_index):
			return true
	
	# Check axes (with some threshold to avoid jitter)
	for axis_index in range(6):
		var axis_value = Input.get_joy_axis(device_id, axis_index)
		if abs(axis_value) > 0.5:
			return true
	
	return false

func _assign_to_available_slot(device_id: int) -> void:
	"""Assign a gamepad to the first available player slot."""
	var gamepads = input_settings.get_gamepads()
	
	for slot in range(input_settings.get_max_players()):
		if gamepads.get(slot, -1) < 0:
			input_settings.assign_gamepad(slot, device_id)
			_update_ui()
			return

func _on_gamepad_connected(player_slot: int, device_id: int) -> void:
	"""Called when a gamepad is connected and assigned."""
	print("PlayerSelect: Gamepad connected to Player %d (device %d)" % [player_slot + 1, device_id])
	_update_ui()
	_update_gamepad_list()

func _on_gamepad_disconnected(player_slot: int, device_id: int) -> void:
	"""Called when a gamepad is disconnected."""
	print("PlayerSelect: Gamepad disconnected from Player %d (device %d)" % [player_slot + 1, device_id])
	_update_ui()
	_update_gamepad_list()

func _on_controller_assignment_changed() -> void:
	"""Called when controller assignments change."""
	_update_ui()
	_update_gamepad_list()

func _update_ui() -> void:
	"""Update all UI elements to reflect current gamepad assignments."""
	_update_player_slot(PLAYER1_SLOT, player1_name_label, player1_status_label, player1_press_hint)
	_update_player_slot(PLAYER2_SLOT, player2_name_label, player2_status_label, player2_press_hint)
	
	# Update start button state
	start_button.disabled = not is_ready_to_play()

func _update_player_slot(slot: int, name_label: Label, status_label: Label, press_hint: Label) -> void:
	"""Update a single player slot's UI."""
	var gamepads = input_settings.get_gamepads()
	var device_id = gamepads.get(slot, -1)
	
	if device_id >= 0:
		# Gamepad is assigned
		var gamepad_name = Input.get_joy_name(device_id)
		status_label.text = gamepad_name
		status_label.modulate = Color(0.2, 1, 0.2)  # Green for connected
		press_hint.visible = false
	else:
		# No gamepad assigned
		status_label.text = "Not Connected"
		status_label.modulate = Color(1, 0.5, 0.2)  # Orange for waiting
		press_hint.visible = true

func is_ready_to_play() -> bool:
	"""Returns true if at least 1 gamepad is connected (single-player mode supported)."""
	# In debug mode, always ready
	if debug_settings and debug_settings.single_player_mode:
		return true
	return input_settings.get_connected_joypad_count() >= 1

func get_assigned_gamepad_count() -> int:
	"""Returns the number of currently assigned gamepads."""
	return input_settings.get_assigned_joypad_count()

func _on_player1_panel_input(event: InputEvent) -> void:
	"""Handle click on Player 1 panel for manual reassignment."""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_gamepad_selection(PLAYER1_SLOT)

func _on_player2_panel_input(event: InputEvent) -> void:
	"""Handle click on Player 2 panel for manual reassignment."""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_gamepad_selection(PLAYER2_SLOT)

func _open_gamepad_selection(slot: int) -> void:
	"""Open the gamepad selection popup for a specific player slot."""
	selected_slot = slot
	_update_gamepad_list()
	gamepad_list_panel.visible = true

func _update_gamepad_list() -> void:
	"""Populate the gamepad list with available controllers."""
	# Clear existing items
	for child in gamepad_list_container.get_children():
		child.queue_free()
	
	var gamepads = input_settings.get_gamepads()
	var connected_joypads = Input.get_connected_joypads()
	
	# Add connected gamepads
	for device_id in connected_joypads:
		var button = Button.new()
		var gamepad_name = Input.get_joy_name(device_id)
		
		# Check if already assigned and to whom
		var assigned_to := -1
		for slot in range(input_settings.get_max_players()):
			if gamepads.get(slot, -1) == device_id:
				assigned_to = slot + 1
				break
		
		if assigned_to >= 0:
			button.text = "%s (Player %d)" % [gamepad_name, assigned_to]
			button.disabled = true
		else:
			button.text = "%s (Available)" % gamepad_name
			button.pressed.connect(_on_gamepad_selected.bind(device_id))
		
		gamepad_list_container.add_child(button)
	
	# Add "Unassign" option if the selected slot has a gamepad
	if selected_slot >= 0 and gamepads.get(selected_slot, -1) >= 0:
		var unassign_button = Button.new()
		unassign_button.text = "Unassign Player %d" % (selected_slot + 1)
		unassign_button.pressed.connect(_on_unassign_pressed)
		gamepad_list_container.add_child(unassign_button)
	
	# Add Close button
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_close_gamepad_selection)
	gamepad_list_container.add_child(close_button)

func _on_gamepad_selected(device_id: int) -> void:
	"""Handle gamepad selection from the list."""
	if selected_slot >= 0:
		input_settings.assign_gamepad(selected_slot, device_id)
		_close_gamepad_selection()
		_update_ui()

func _on_unassign_pressed() -> void:
	"""Unassign the gamepad from the selected slot."""
	if selected_slot >= 0:
		input_settings.unassign_gamepad(selected_slot)
	_update_ui()
	_close_gamepad_selection()

func _close_gamepad_selection() -> void:
	"""Close the gamepad selection popup."""
	gamepad_list_panel.visible = false
	selected_slot = -1

func _on_start_pressed() -> void:
	"""Start the game with current controller assignments."""
	if is_ready_to_play():
		player_assignment_complete.emit()
		# Load the game scene with null check guard
		var tree = get_tree()
		if tree:
			tree.change_scene_to_file("res://scenes/game.tscn")

func _on_back_pressed() -> void:
	"""Return to the main menu."""
	back_to_menu.emit()
	# Hide this screen - parent should handle showing main menu
	queue_free()
