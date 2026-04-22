extends Node

var rebinding_action: String = ""
var rebinding_player: String = ""
var waiting_for_input: bool = false

signal binding_complete(action: String, player: String)
signal binding_cancelled()
signal binding_duplicate()

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
		return a.button_index == b.button_index and a.device == b.device
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis and sign(a.axis_value) == sign(b.axis_value)
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
