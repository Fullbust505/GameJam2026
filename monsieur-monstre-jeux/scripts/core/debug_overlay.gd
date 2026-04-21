extends Control

# Debug Overlay - Shows game state information when debug mode is enabled
# Press F3 to toggle visibility (in debug mode)

@onready var state_label: Label = $VBox/StateLabel
@onready var turn_label: Label = $VBox/TurnLabel
@onready var player_info_label: Label = $VBox/PlayerInfoLabel
@onready var controls_label: Label = $VBox/ControlsLabel

var _game_state: Node = null
var _input_settings: Node = null
var _debug_settings: Node = null

func _ready() -> void:
	_game_state = get_node_or_null("/root/GameState")
	_input_settings = get_node_or_null("/root/InputSettings")
	_debug_settings = get_node_or_null("/root/DebugSettings")
	
	# Start hidden
	visible = false
	
	# Check if debug mode should auto-show this
	if _debug_settings and _debug_settings.debug_overlay_visible:
		visible = true

func _process(_delta: float) -> void:
	if not visible:
		return
	_update_debug_info()

func _update_debug_info() -> void:
	"""Update all debug information display."""
	# Update state
	if _game_state:
		state_label.text = "Game State: %s" % _game_state.get_state_name()
		
		# Turn info
		var current_turn = _game_state.get_current_player()
		turn_label.text = "Current Turn: Player %d" % (current_turn + 1)
	else:
		state_label.text = "Game State: N/A"
		turn_label.text = "Current Turn: N/A"
	
	# Player info
	if _input_settings:
		var gamepads = _input_settings.get_gamepads()
		var info = "Players:\n"
		for slot in range(_input_settings.get_max_players()):
			var device_id = gamepads.get(slot, -1)
			if device_id >= 0:
				var name = Input.get_joy_name(device_id)
				info += "  P%d: %s (dev%d)\n" % [slot + 1, name, device_id]
			else:
				info += "  P%d: Not connected\n" % [slot + 1]
		player_info_label.text = info
	else:
		player_info_label.text = "Players: N/A"
	
	# Controls hint
	controls_label.text = "F3: Toggle Overlay | F4: Pause | F5: Skip Turn"

func _input(event: InputEvent) -> void:
	# Check for debug key presses (F3 to toggle)
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F3:
				visible = !visible
				if _debug_settings:
					_debug_settings.debug_overlay_visible = visible
			KEY_F4:
				# Toggle pause
				if get_tree():
					if get_tree().paused:
						get_tree().paused = false
					else:
						get_tree().paused = true
			KEY_F5:
				# Skip turn (if game state supports it)
				if _game_state and _game_state.has_method("skip_turn"):
					_game_state.skip_turn()

func set_visible_toggle() -> void:
	"""Toggle visibility from external code."""
	visible = !visible
	if _debug_settings:
		_debug_settings.debug_overlay_visible = visible
