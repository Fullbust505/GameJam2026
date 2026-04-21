extends Node

# Input Settings Manager - Dynamic Gamepad Support
# Manages gamepad/controller bindings for Monsieur Monstre
# Supports 1-4 players with any combination of connected controllers
# First controller to connect = Player 1, second = Player 2, etc.

signal binding_changed(action: String, event: InputEvent)
signal gamepad_connected(player_slot: int, device_id: int)
signal gamepad_disconnected(player_slot: int, device_id: int)
signal controller_assignment_changed()

# Player action sets
const PLAYER1_ACTIONS := [
	"player1_up", "player1_down", "player1_left", "player1_right",
	"player1_action", "player1_secondary"
]

const PLAYER2_ACTIONS := [
	"player2_up", "player2_down", "player2_left", "player2_right",
	"player2_action", "player2_secondary"
]

const PLAYER3_ACTIONS := [
	"player3_up", "player3_down", "player3_left", "player3_right",
	"player3_action", "player3_secondary"
]

const PLAYER4_ACTIONS := [
	"player4_up", "player4_down", "player4_left", "player4_right",
	"player4_action", "player4_secondary"
]

# Menu navigation actions
const MENU_ACTIONS := [
	"menu_up", "menu_down", "menu_left", "menu_right",
	"menu_accept", "menu_cancel"
]

# Debug actions (keyboard only in debug mode)
const DEBUG_ACTIONS := [
	"debug_toggle_overlay", "debug_toggle_pause", "debug_skip_turn",
	"debug_force_win_p1", "debug_force_win_p2"
]

# All player actions combined
const PLAYER_ACTIONS := PLAYER1_ACTIONS + PLAYER2_ACTIONS + PLAYER3_ACTIONS + PLAYER4_ACTIONS
const ALL_ACTIONS := PLAYER_ACTIONS + MENU_ACTIONS + DEBUG_ACTIONS

# Player slot constants
const PLAYER1_SLOT := 0
const PLAYER2_SLOT := 1
const PLAYER3_SLOT := 2
const PLAYER4_SLOT := 3

# Maximum players
const MAX_PLAYERS := 4

# Joypad button constants
const JOY_BUTTON_A := 0
const JOY_BUTTON_B := 1
const JOY_BUTTON_X := 2
const JOY_BUTTON_Y := 3
const JOY_BUTTON_LEFT_SHOULDER := 4
const JOY_BUTTON_RIGHT_SHOULDER := 5
const JOY_BUTTON_LEFT_STICK := 6
const JOY_BUTTON_RIGHT_STICK := 7
const JOY_BUTTON_DPAD_UP := 8
const JOY_BUTTON_DPAD_DOWN := 9
const JOY_BUTTON_DPAD_LEFT := 10
const JOY_BUTTON_DPAD_RIGHT := 11
const JOY_BUTTON_BACK := 8
const JOY_BUTTON_START := 9
const JOY_BUTTON_GUIDE := 12

const JOY_AXIS_LEFT_X := 0
const JOY_AXIS_LEFT_Y := 1
const JOY_AXIS_RIGHT_X := 2
const JOY_AXIS_RIGHT_Y := 3
const JOY_AXIS_TRIGGER_LEFT := 4
const JOY_AXIS_TRIGGER_RIGHT := 5

# Config file path
const CONFIG_SECTION := "input_bindings"
const CONFIG_FILE := "user://input_settings.cfg"

# Cached config file
var _config: ConfigFile = null

# Connected gamepad tracking - device_id -> player_slot mapping
# Also tracks player_slot -> device_id
var _device_to_slot: Dictionary = {}  # device_id -> player_slot
var _slot_to_device: Dictionary = {}   # player_slot -> device_id

# Debug settings reference
var _debug_settings: Node = null

func _ready() -> void:
	_initialize_default_actions()
	load_bindings()
	
	# Monitor gamepad connection/disconnection
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	
	# Initialize slot mappings
	for i in range(MAX_PLAYERS):
		_slot_to_device[i] = -1
	
	# Get debug settings if available
	_debug_settings = get_node_or_null("/root/DebugSettings")
	
	# Check for already connected gamepads
	_detect_connected_gamepads()

func _initialize_default_actions() -> void:
	"""Initialize default InputMap actions if they don't exist."""
	for action in ALL_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.action_add_event(action, _get_default_event(action))

func _get_default_event(action: String) -> InputEvent:
	"""Returns the default input event for an action."""
	# Check if this is a debug action (keyboard only in debug mode)
	if action in DEBUG_ACTIONS:
		return _get_default_debug_event(action)
	
	# Player actions - use any available gamepad
	if action in PLAYER1_ACTIONS:
		return _create_player_action_event(action, PLAYER1_SLOT)
	elif action in PLAYER2_ACTIONS:
		return _create_player_action_event(action, PLAYER2_SLOT)
	elif action in PLAYER3_ACTIONS:
		return _create_player_action_event(action, PLAYER3_SLOT)
	elif action in PLAYER4_ACTIONS:
		return _create_player_action_event(action, PLAYER4_SLOT)
	elif action in MENU_ACTIONS:
		return _create_menu_action_event(action)
	
	return InputEventJoypadButton.new()

func _create_player_action_event(action: String, player_slot: int) -> InputEventJoypadButton:
	var event = InputEventJoypadButton.new()
	event.set_device(player_slot)  # Device will be resolved dynamically later
	
	# Use device-agnostic buttons by default (D-pad and A/X)
	if "up" in action:
		event.set_button_index(JOY_BUTTON_DPAD_UP)
	elif "down" in action:
		event.set_button_index(JOY_BUTTON_DPAD_DOWN)
	elif "left" in action:
		event.set_button_index(JOY_BUTTON_DPAD_LEFT)
	elif "right" in action:
		event.set_button_index(JOY_BUTTON_DPAD_RIGHT)
	elif "action" in action:
		event.set_button_index(JOY_BUTTON_A)
	elif "secondary" in action:
		event.set_button_index(JOY_BUTTON_X)
	
	return event

func _create_menu_action_event(action: String) -> InputEventJoypadButton:
	var event = InputEventJoypadButton.new()
	event.set_device(0)  # Menu uses first controller
	
	if "up" in action:
		event.set_button_index(JOY_BUTTON_DPAD_UP)
	elif "down" in action:
		event.set_button_index(JOY_BUTTON_DPAD_DOWN)
	elif "left" in action:
		event.set_button_index(JOY_BUTTON_DPAD_LEFT)
	elif "right" in action:
		event.set_button_index(JOY_BUTTON_DPAD_RIGHT)
	elif "accept" in action:
		event.set_button_index(JOY_BUTTON_A)
	elif "cancel" in action:
		event.set_button_index(JOY_BUTTON_B)
	
	return event

func _get_default_debug_event(action: String) -> InputEventKey:
	var event = InputEventKey.new()
	match action:
		"debug_toggle_overlay":
			event.keycode = KEY_F3
		"debug_toggle_pause":
			event.keycode = KEY_F4
		"debug_skip_turn":
			event.keycode = KEY_F5
		"debug_force_win_p1":
			event.keycode = KEY_F9
		"debug_force_win_p2":
			event.keycode = KEY_F10
	return event

func map_action_to_event(action: String, event: InputEvent) -> bool:
	"""Maps an action to an input event. Returns true if successful."""
	if not action in ALL_ACTIONS:
		push_warning("InputSettings: Unknown action '%s'" % action)
		return false
	
	if event == null:
		push_warning("InputSettings: Cannot map null event to action '%s'" % action)
		return false
	
	# Validate event type
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventKey):
		push_warning("InputSettings: Invalid event type for action '%s'" % action)
		return false
	
	# Remove existing events for this action
	var existing_events = InputMap.action_get_events(action)
	for existing_event in existing_events:
		InputMap.action_erase_event(action, existing_event)
	
	# Add the new event
	InputMap.action_add_event(action, event)
	binding_changed.emit(action, event)
	
	return true

func get_action_binding(action: String) -> Array:
	"""Returns current binding(s) for an action as an array of InputEvents."""
	if not action in ALL_ACTIONS:
		push_warning("InputSettings: Unknown action '%s'" % action)
		return []
	return InputMap.action_get_events(action)

func get_action_binding_text(action: String, player_slot: int = -1) -> String:
	"""Returns a human-readable string describing the current binding."""
	var events = get_action_binding(action)
	if events.is_empty():
		return "Not bound"
	
	var descriptions: Array = []
	for event in events:
		descriptions.append(_get_event_description(event, player_slot))
	
	return ", ".join(descriptions)

func _get_event_description(event: InputEvent, player_slot: int = -1) -> String:
	"""Returns a human-readable description of an InputEvent."""
	if event is InputEventJoypadButton:
		var btn_event = event as InputEventJoypadButton
		var device = btn_event.get_device()
		var btn_name = _get_joypad_button_name(btn_event.get_button_index())
		if player_slot >= 0:
			return "P%d:%s" % [player_slot + 1, btn_name]
		# Show actual device ID
		if device >= 0:
			return "Dev%d:%s" % [device, btn_name]
		return btn_name
	elif event is InputEventJoypadMotion:
		var mot_event = event as InputEventJoypadMotion
		return _get_joypad_axis_name(mot_event.get_axis(), mot_event.get_axis_value())
	elif event is InputEventKey:
		var key_event = event as InputEventKey
		return _get_key_name(key_event.keycode)
	return "Unknown"

func _get_joypad_button_name(button_index: int) -> String:
	match button_index:
		0: return "A"
		1: return "B"
		2: return "X"
		3: return "Y"
		4: return "LB"
		5: return "RB"
		6: return "L3"
		7: return "R3"
		8: return "D-Up"
		9: return "D-Down"
		10: return "D-Left"
		11: return "D-Right"
		12: return "Home"
	return "Button %d" % button_index

func _get_joypad_axis_name(axis: int, value: float) -> String:
	var direction = "+" if value >= 0 else "-"
	match axis:
		0: return "LStick-X%s" % direction
		1: return "LStick-Y%s" % direction
		2: return "RStick-X%s" % direction
		3: return "RStick-Y%s" % direction
		4: return "LT%s" % direction
		5: return "RT%s" % direction
	return "Axis %d%s" % [axis, direction]

func _get_key_name(keycode: int) -> String:
	match keycode:
		KEY_F1: return "F1"
		KEY_F2: return "F2"
		KEY_F3: return "F3"
		KEY_F4: return "F4"
		KEY_F5: return "F5"
		KEY_F6: return "F6"
		KEY_F7: return "F7"
		KEY_F8: return "F8"
		KEY_F9: return "F9"
		KEY_F10: return "F10"
		KEY_F11: return "F11"
		KEY_F12: return "F12"
		KEY_SPACE: return "Space"
		KEY_ENTER: return "Enter"
		KEY_ESCAPE: return "Esc"
		KEY_TAB: return "Tab"
	return "Key%d" % keycode

func reset_to_defaults() -> void:
	"""Resets all bindings to their default values."""
	for action in ALL_ACTIONS:
		var existing_events = InputMap.action_get_events(action)
		for evt in existing_events:
			InputMap.action_erase_event(action, evt)
		
		var default_event = _get_default_event(action)
		InputMap.action_add_event(action, default_event)
		binding_changed.emit(action, default_event)

func save_bindings() -> bool:
	"""Saves current bindings to config file. Returns true if successful."""
	_config = ConfigFile.new()
	
	for action in ALL_ACTIONS:
		var events = InputMap.action_get_events(action)
		if events.is_empty():
			continue
		
		var event_strings: Array = []
		for event in events:
			event_strings.append(_serialize_event(event))
		
		_config.set_value(CONFIG_SECTION, action, event_strings)
	
	# Save device assignments
	_config.set_value(CONFIG_SECTION, "device_to_slot", _device_to_slot)
	_config.set_value(CONFIG_SECTION, "slot_to_device", _slot_to_device)
	
	var err = _config.save(CONFIG_FILE)
	if err != OK:
		push_error("InputSettings: Failed to save bindings: %d" % err)
		return false
	
	return true

func load_bindings() -> bool:
	"""Loads saved bindings from config file. Returns true if successful."""
	_config = ConfigFile.new()
	
	var err = _config.load(CONFIG_FILE)
	if err != OK:
		return false
	
	for action in ALL_ACTIONS:
		if not _config.has_section_key(CONFIG_SECTION, action):
			continue
		
		var event_strings = _config.get_value(CONFIG_SECTION, action)
		if event_strings == null:
			continue
		
		var existing_events = InputMap.action_get_events(action)
		for evt in existing_events:
			InputMap.action_erase_event(action, evt)
		
		for event_string in event_strings:
			var event = _deserialize_event(event_string)
			if event != null:
				InputMap.action_add_event(action, event)
	
	# Load device assignments
	if _config.has_section_key(CONFIG_SECTION, "device_to_slot"):
		_device_to_slot = _config.get_value(CONFIG_SECTION, "device_to_slot")
	if _config.has_section_key(CONFIG_SECTION, "slot_to_device"):
		_slot_to_device = _config.get_value(CONFIG_SECTION, "slot_to_device")
	
	return true

func _serialize_event(event: InputEvent) -> String:
	if event is InputEventJoypadButton:
		var btn_event = event as InputEventJoypadButton
		return "joybtn:%d:%d" % [btn_event.get_device(), btn_event.get_button_index()]
	elif event is InputEventJoypadMotion:
		var mot_event = event as InputEventJoypadMotion
		return "joymot:%d:%d:%.3f" % [mot_event.get_device(), mot_event.get_axis(), mot_event.get_axis_value()]
	elif event is InputEventKey:
		var key_event = event as InputEventKey
		return "key:%d" % key_event.keycode
	return ""

func _deserialize_event(event_string: String) -> InputEvent:
	var parts = event_string.split(":")
	if parts.is_empty():
		return null
	
	var event_type = parts[0]
	
	match event_type:
		"joybtn":
			if parts.size() < 3:
				return null
			var event = InputEventJoypadButton.new()
			event.set_device(int(parts[1]))
			event.set_button_index(int(parts[2]))
			return event
		"joymot":
			if parts.size() < 4:
				return null
			var event = InputEventJoypadMotion.new()
			event.set_device(int(parts[1]))
			event.set_axis(int(parts[2]))
			event.set_axis_value(float(parts[3]))
			return event
		"key":
			if parts.size() < 2:
				return null
			var event = InputEventKey.new()
			event.keycode = int(parts[1])
			return event
	
	return null

func _detect_connected_gamepads() -> void:
	"""Detect currently connected gamepads and assign them to players."""
	var connected = Input.get_connected_joypads()
	
	# Clear old mappings
	_device_to_slot.clear()
	for i in range(MAX_PLAYERS):
		_slot_to_device[i] = -1
	
	# Assign connected gamepads to player slots in order
	var slot_idx = 0
	for device_id in connected:
		if slot_idx >= MAX_PLAYERS:
			break
		_assign_device_to_slot(device_id, slot_idx)
		slot_idx += 1
	
	_update_action_devices()

func _assign_device_to_slot(device_id: int, player_slot: int) -> bool:
	"""Assign a device to a player slot."""
	if player_slot < 0 or player_slot >= MAX_PLAYERS:
		return false
	
	# Remove from old slot if any
	var old_slot = _device_to_slot.get(device_id, -1)
	if old_slot >= 0:
		_slot_to_device[old_slot] = -1
	
	_device_to_slot[device_id] = player_slot
	_slot_to_device[player_slot] = device_id
	
	return true

func assign_gamepad(player_slot: int, device_id: int) -> bool:
	"""Assign a gamepad device to a player slot."""
	if player_slot < 0 or player_slot >= MAX_PLAYERS:
		return false
	
	# Check if device is connected
	var connected = Input.get_connected_joypads()
	if device_id not in connected:
		push_warning("InputSettings: Gamepad device %d is not connected" % device_id)
		return false
	
	_assign_device_to_slot(device_id, player_slot)
	_update_action_devices()
	controller_assignment_changed.emit()
	
	print("InputSettings: Assigned gamepad %d to Player %d" % [device_id, player_slot + 1])
	return true

func unassign_gamepad(player_slot: int) -> bool:
	"""Unassign a gamepad from a player slot."""
	if player_slot < 0 or player_slot >= MAX_PLAYERS:
		return false
	
	var device_id = _slot_to_device.get(player_slot, -1)
	if device_id < 0:
		# No gamepad assigned to this slot
		return false
	
	# Remove from mappings
	_slot_to_device[player_slot] = -1
	_device_to_slot.erase(device_id)
	
	controller_assignment_changed.emit()
	
	print("InputSettings: Unassigned gamepad %d from Player %d" % [device_id, player_slot + 1])
	return true

func _update_action_devices() -> void:
	"""Update all action events to use the correct device IDs."""
	# This is called when controller assignments change
	# The InputMap events already have device IDs embedded
	pass

func get_gamepads() -> Dictionary:
	"""Returns the current gamepad assignments (slot -> device_id)."""
	return _slot_to_device.duplicate()

func get_connected_gamepad_ids() -> Array:
	"""Returns list of all connected device IDs."""
	return Input.get_connected_joypads()

func get_player_slot_for_device(device_id: int) -> int:
	"""Returns which player slot a device is assigned to, or -1 if unassigned."""
	return _device_to_slot.get(device_id, -1)

func is_gamepad_connected(player_slot: int) -> bool:
	"""Returns true if the specified player's gamepad is connected."""
	if player_slot < 0 or player_slot >= MAX_PLAYERS:
		return false
	return _slot_to_device.get(player_slot, -1) >= 0

func get_gamepad_name(player_slot: int) -> String:
	"""Returns the name of the connected gamepad for a player slot."""
	var device_id = _slot_to_device.get(player_slot, -1)
	if device_id < 0:
		return "Not Connected"
	return Input.get_joy_name(device_id)

func get_connected_joypad_count() -> int:
	"""Returns the number of connected gamepads."""
	return Input.get_connected_joypads().size()

func get_assigned_joypad_count() -> int:
	"""Returns the number of gamepads currently assigned to player slots."""
	var count = 0
	for i in range(MAX_PLAYERS):
		if _slot_to_device.get(i, -1) >= 0:
			count += 1
	return count

func get_device_for_slot(slot: int) -> int:
	"""Get the device ID assigned to a slot, or -1 if none."""
	return _slot_to_device.get(slot, -1)

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	"""Called when a gamepad is connected or disconnected."""
	if connected:
		print("InputSettings: Gamepad connected (device %d: %s)" % [device_id, Input.get_joy_name(device_id)])
		_handle_gamepad_connect(device_id)
	else:
		print("InputSettings: Gamepad disconnected (device %d)" % device_id)
		_handle_gamepad_disconnect(device_id)

func _handle_gamepad_connect(device_id: int) -> void:
	"""Handle gamepad connection - assign to first available slot."""
	# Check if already assigned
	if device_id in _device_to_slot:
		return
	
	# Find first available slot
	for slot in range(MAX_PLAYERS):
		if _slot_to_device.get(slot, -1) < 0:
			_assign_device_to_slot(device_id, slot)
			gamepad_connected.emit(slot, device_id)
			controller_assignment_changed.emit()
			return

func _handle_gamepad_disconnect(device_id: int) -> void:
	"""Handle gamepad disconnection."""
	var old_slot = _device_to_slot.get(device_id, -1)
	if old_slot >= 0:
		_slot_to_device[old_slot] = -1
		_device_to_slot.erase(device_id)
		gamepad_disconnected.emit(old_slot, device_id)
		
		# Reassign remaining controllers to fill gaps
		_reassign_controllers()
		controller_assignment_changed.emit()

func _reassign_controllers() -> void:
	"""Reassign controllers to fill empty slots after disconnection."""
	var connected = Input.get_connected_joypads()
	var available_devices: Array = []
	
	# Find devices not currently assigned
	for device_id in connected:
		if device_id not in _device_to_slot:
			available_devices.append(device_id)
	
	# Fill empty slots with available devices
	for slot in range(MAX_PLAYERS):
		if _slot_to_device.get(slot, -1) < 0 and available_devices.size() > 0:
			var device_id = available_devices.pop_front()
			_assign_device_to_slot(device_id, slot)
			gamepad_connected.emit(slot, device_id)

# Helper functions for checking actions
func is_action_pressed(action: String) -> bool:
	"""Returns true if the given action is currently pressed."""
	return Input.is_action_pressed(action)

func is_action_just_pressed(action: String) -> bool:
	"""Returns true if the given action was just pressed this frame."""
	return Input.is_action_just_pressed(action)

func is_action_just_released(action: String) -> bool:
	"""Returns true if the given action was just released this frame."""
	return Input.is_action_just_released(action)

func get_action_display_name(action: String) -> String:
	"""Returns a human-readable name for an action."""
	if action in PLAYER1_ACTIONS:
		return "Player 1 - " + _action_short_name(action)
	elif action in PLAYER2_ACTIONS:
		return "Player 2 - " + _action_short_name(action)
	elif action in PLAYER3_ACTIONS:
		return "Player 3 - " + _action_short_name(action)
	elif action in PLAYER4_ACTIONS:
		return "Player 4 - " + _action_short_name(action)
	elif action in MENU_ACTIONS:
		return "Menu - " + _action_short_name(action)
	elif action in DEBUG_ACTIONS:
		return "Debug - " + _action_short_name(action)
	return action

func _action_short_name(action: String) -> String:
	var name = action
	for prefix in ["player1_", "player2_", "player3_", "player4_", "menu_", "debug_"]:
		name = name.replace(prefix, "")
	return name.capitalize()

func get_action_category(action: String) -> String:
	"""Returns the category of an action."""
	if action in PLAYER1_ACTIONS:
		return "player1"
	elif action in PLAYER2_ACTIONS:
		return "player2"
	elif action in PLAYER3_ACTIONS:
		return "player3"
	elif action in PLAYER4_ACTIONS:
		return "player4"
	elif action in MENU_ACTIONS:
		return "menu"
	elif action in DEBUG_ACTIONS:
		return "debug"
	return ""

# Get actions for a specific player
func get_player_actions(player_slot: int) -> Array:
	match player_slot:
		PLAYER1_SLOT:
			return PLAYER1_ACTIONS.duplicate()
		PLAYER2_SLOT:
			return PLAYER2_ACTIONS.duplicate()
		PLAYER3_SLOT:
			return PLAYER3_ACTIONS.duplicate()
		PLAYER4_SLOT:
			return PLAYER4_ACTIONS.duplicate()
	return []

func get_max_players() -> int:
	return MAX_PLAYERS

func get_player_count() -> int:
	"""Returns the number of currently connected/assigned players."""
	var count = 0
	for i in range(MAX_PLAYERS):
		if _slot_to_device.get(i, -1) >= 0:
			count += 1
	return max(count, 1)  # At least 1 for single player
