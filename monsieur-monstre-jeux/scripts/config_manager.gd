extends Node

const CONFIG_PATH = "res://config.json"
var config: Dictionary = {}

func _ready():
	load_config()

func load_config() -> Dictionary:
	if FileAccess.file_exists(CONFIG_PATH):
		var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if file != null:
			var json = JSON.new()
			var json_text = file.get_as_text()
			if json_text.is_empty():
				config = get_default_config()
			else:
				json.parse(json_text)
				config = json.data if json.data else get_default_config()
			file.close()
		else:
			config = get_default_config()
	else:
		config = get_default_config()
		save_config()
	apply_display_settings()
	apply_input_mappings()
	return config

func save_config():
	var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config, '\t'))
		file.close()

func get_default_config() -> Dictionary:
	return {
		"display": {"width": 1280, "height": 720, "fullscreen": false, "vsync": true},
		"input": {
			"p1": {
				"move_left": {"type": "joypad_axis", "device": 0, "axis": 0, "value": -1.0},
				"move_right": {"type": "joypad_axis", "device": 0, "axis": 0, "value": 1.0},
				"move_up": {"type": "joypad_axis", "device": 0, "axis": 1, "value": -1.0},
				"move_down": {"type": "joypad_axis", "device": 0, "axis": 1, "value": 1.0},
				"main_button": {"type": "joypad_button", "device": 0, "button_index": 0},
				"sub_button": {"type": "joypad_button", "device": 0, "button_index": 1},
				"l1": {"type": "joypad_button", "device": 0, "button_index": 9},
				"r1": {"type": "joypad_button", "device": 0, "button_index": 10}
			},
			"p2": {
				"move_left": {"type": "joypad_axis", "device": 1, "axis": 0, "value": -1.0},
				"move_right": {"type": "joypad_axis", "device": 1, "axis": 0, "value": 1.0},
				"move_up": {"type": "joypad_axis", "device": 1, "axis": 1, "value": -1.0},
				"move_down": {"type": "joypad_axis", "device": 1, "axis": 1, "value": 1.0},
				"main_button": {"type": "joypad_button", "device": 1, "button_index": 0},
				"sub_button": {"type": "joypad_button", "device": 1, "button_index": 1},
				"l1": {"type": "joypad_button", "device": 1, "button_index": 9},
				"r1": {"type": "joypad_button", "device": 1, "button_index": 10}
			}
		}
	}

func apply_display_settings():
	var display = config.get("display", {})
	var width = display.get("width", 1280)
	var height = display.get("height", 720)
	var fullscreen = display.get("fullscreen", false)
	var vsync = display.get("vsync", true)

	get_window().size = Vector2i(width, height)
	get_window().mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

func apply_input_mappings():
	for action in ["p1_move_left", "p1_move_right", "p1_move_up", "p1_move_down",
				   "p2_move_left", "p2_move_right", "p2_move_up", "p2_move_down",
				   "p1_l1", "p1_r1", "p1_main_button", "p1_sub_button",
				   "p2_l1", "p2_r1", "p2_main_button", "p2_sub_button"]:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)

	var input_config = config.get("input", {})
	for player in ["p1", "p2"]:
		if not input_config.has(player):
			continue
		for action_name in input_config[player]:
			var binding = input_config[player][action_name]
			var event = create_input_event(binding)
			if event:
				InputMap.action_add_event(player + "_" + action_name, event)

func create_input_event(binding: Dictionary) -> InputEvent:
	match binding.get("type"):
		"key":
			var event = InputEventKey.new()
			event.physical_keycode = binding.get("physical_keycode", 0)
			return event
		"joypad_button":
			var event = InputEventJoypadButton.new()
			event.device = binding.get("device", 0)
			event.button_index = binding.get("button_index", 0)
			return event
		"joypad_axis":
			var event = InputEventJoypadMotion.new()
			event.device = binding.get("device", 0)
			event.axis = binding.get("axis", 0)
			event.axis_value = binding.get("value", 1.0)
			return event
	return null

func get_binding_display(player: String, action: String) -> String:
	var full_action = player + "_" + action
	var events = InputMap.action_get_events(full_action)
	if events.is_empty():
		return "Unbound"
	return get_event_display_string(events[0])

func get_event_display_string(event: InputEvent) -> String:
	if event is InputEventKey:
		return event.as_text()
	if event is InputEventJoypadButton:
		return "JS%d" % event.button_index
	if event is InputEventJoypadMotion:
		var axis_names = ["LX", "LY", "RX", "RY", "L2", "R2"]
		var axis_idx = event.axis if event.axis < axis_names.size() else event.axis
		return "%s%s" % [axis_names[axis_idx] if axis_idx < axis_names.size() else "AX%d" % event.axis, "+" if event.axis_value > 0 else "-"]
	return "?"
