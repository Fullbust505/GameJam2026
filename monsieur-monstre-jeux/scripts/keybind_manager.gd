extends Node

var rebinding_action: String = ""
var rebinding_player: String = ""
var waiting_for_input: bool = false

signal binding_complete(action: String, player: String)
signal binding_cancelled()
signal binding_duplicate()

# Joypad connection tracking - dynamically maps player to physical device
var player_devices: Array = [0, 1]  # Default: P1=device 0, P2=device 1

func _ready():
	# Sync with currently connected joypads
	_sanitize_joypad_devices()
	# Listen for joypad connection/disconnection
	Input.joy_connection_changed.connect(_on_joypad_connection)

var _known_connected_devices: Array = []

func _on_joypad_connection(device: int, connected: bool):
	if connected:
		if device not in _known_connected_devices:
			_known_connected_devices.append(device)
	else:
		_known_connected_devices.erase(device)
	# Rebuild player_devices based on current connection order
	_known_connected_devices.sort()
	if _known_connected_devices.size() >= 1:
		player_devices[0] = _known_connected_devices[0]
	else:
		player_devices[0] = 0
	if _known_connected_devices.size() >= 2:
		player_devices[1] = _known_connected_devices[1]
	else:
		player_devices[1] = 1
	print("Player devices: P1=joy%d, P2=joy%d (known: %s)" % [player_devices[0], player_devices[1], _known_connected_devices])

func _sanitize_joypad_devices():
	print("Joypad devices sanitized: P1=joy%d, P2=joy%d" % [player_devices[0], player_devices[1]])

# Get the device index for a player (0-indexed)
func get_device_for_player(player_idx: int) -> int:
	if player_idx < player_devices.size():
		return player_devices[player_idx]
	return player_idx

# Check if a joypad button is pressed for a given player
func is_button_pressed(player_idx: int, button: int) -> bool:
	return Input.is_joy_button_pressed(get_device_for_player(player_idx), button)

# Get joy axis value for a player
func get_joy_axis(player_idx: int, axis: int) -> float:
	return Input.get_joy_axis(get_device_for_player(player_idx), axis)

func get_connected_joypad_count() -> int:
	return player_devices.size()

func _input(event: InputEvent):
	if not waiting_for_input:
		return

	# Ignore keyboard/mouse - gamepad only
	if event is InputEventKey or event is InputEventMouse or event is InputEventMouseButton:
		return

	# For joypad motion, require significant movement to avoid drift
	if event is InputEventJoypadMotion and abs(event.axis_value) < 0.5:
		return

	# Check for duplicate binding
	if is_duplicate_binding(event):
		binding_duplicate.emit()
		waiting_for_input = false
		return

	apply_binding(event)
	waiting_for_input = false
	binding_complete.emit(rebinding_action, rebinding_player)

func start_rebinding(action: String, player: String):
	rebinding_action = action
	rebinding_player = player
	waiting_for_input = true

func cancel_rebinding():
	waiting_for_input = false
	binding_cancelled.emit()

func is_duplicate_binding(event: InputEvent) -> bool:
	for existing_action in InputMap.get_actions():
		for existing_event in InputMap.action_get_events(existing_action):
			if events_match(event, existing_event):
				return true
	return false

func events_match(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.device == b.device and a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.device == b.device and a.axis == b.axis and sign(a.axis_value) == sign(b.axis_value)
	return false

func apply_binding(event: InputEvent):
	var full_action = rebinding_player + "_" + rebinding_action
	InputMap.action_erase_events(full_action)
	InputMap.action_add_event(full_action, event)

	# Update config and save
	var config = ConfigManager.config
	if not config.has("input"):
		config["input"] = {}
	if not config["input"].has(rebinding_player):
		config["input"][rebinding_player] = {}

	var binding_dict = {}
	if event is InputEventJoypadButton:
		binding_dict = {"type": "joypad_button", "device": event.device, "button_index": event.button_index}
	elif event is InputEventJoypadMotion:
		binding_dict = {"type": "joypad_axis", "device": event.device, "axis": event.axis, "value": event.axis_value}
	elif event is InputEventKey:
		binding_dict = {"type": "key", "physical_keycode": event.physical_keycode}

	config["input"][rebinding_player][rebinding_action] = binding_dict
	ConfigManager.save_config()
