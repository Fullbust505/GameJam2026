extends Control

# Keybind Screen Controller - Gamepad Only
# UI for rebinding gamepad controls

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var controller_info_label: Label = $Panel/VBox/ControllerInfoLabel
@onready var actions_container: VBoxContainer = $Panel/VBox/Scroll/ActionsContainer
@onready var listening_label: Label = $Panel/VBox/ListeningLabel
@onready var buttons_container: HBoxContainer = $Panel/VBox/ButtonsContainer
@onready var reset_button: Button = $Panel/VBox/ButtonsContainer/ResetButton
@onready var save_button: Button = $Panel/VBox/ButtonsContainer/SaveButton
@onready var back_button: Button = $Panel/VBox/ButtonsContainer/BackButton

# Reference to InputSettings autoload
var input_settings: Node = null

# Current action being rebound
var _listening_action: String = ""

# Action binding UI elements
var _action_labels: Dictionary = {}

const HORIZ_ALIGN_RIGHT := 2

func _ready() -> void:
	input_settings = get_node_or_null("/root/InputSettings")
	
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	if input_settings and input_settings.has_signal("binding_changed"):
		input_settings.binding_changed.connect(_on_binding_changed)
	
	if input_settings and input_settings.has_signal("gamepadconnected"):
		input_settings.gamepadconnected.connect(_on_gamepad_changed)
	if input_settings and input_settings.has_signal("gamepaddisconnected"):
		input_settings.gamepaddisconnected.connect(_on_gamepad_changed)
	
	_build_actions_list()
	_update_controller_info()
	
	if listening_label:
		listening_label.visible = false

func _build_actions_list() -> void:
	"""Build the list of rebindable actions."""
	if not actions_container or not input_settings:
		return
	
	for child in actions_container.get_children():
		child.queue_free()
	_action_labels.clear()
	
	# Build sections for Player 1, Player 2, and Menu
	_build_action_section("Player 1", input_settings.PLAYER1_ACTIONS if "PLAYER1_ACTIONS" in input_settings else [], 0)
	_build_action_section("Player 2", input_settings.PLAYER2_ACTIONS if "PLAYER2_ACTIONS" in input_settings else [], 1)
	_build_action_section("Menu", input_settings.MENU_ACTIONS if "MENU_ACTIONS" in input_settings else [], 0)

func _build_action_section(category_name: String, actions: Array, player_slot: int) -> void:
	"""Build a section for a group of actions."""
	if actions.is_empty():
		return
	
	# Section header
	var header = Label.new()
	header.text = category_name
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(1, 0.8, 0.3, 1))
	actions_container.add_child(header)
	
	for action in actions:
		var row_container = HBoxContainer.new()
		row_container.custom_minimum_size.y = 40
		
		# Player indicator
		var player_indicator = Label.new()
		player_indicator.text = ""
		player_indicator.custom_minimum_size.x = 30
		row_container.add_child(player_indicator)
		
		# Action name label
		var name_label = Label.new()
		var display_name = action
		if input_settings and input_settings.has_method("get_action_display_name"):
			display_name = input_settings.get_action_display_name(action)
		name_label.text = display_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_container.add_child(name_label)
		
		# Current binding label
		var binding_label = Label.new()
		binding_label.name = "BindingLabel"
		binding_label.horizontal_alignment = HORIZ_ALIGN_RIGHT
		binding_label.custom_minimum_size.x = 120
		_update_binding_label(binding_label, action, player_slot)
		row_container.add_child(binding_label)
		
		# Rebind button
		var rebind_btn = Button.new()
		rebind_btn.text = "Bind"
		rebind_btn.pressed.connect(_on_rebind_pressed.bind(action))
		rebind_btn.custom_minimum_size.x = 60
		row_container.add_child(rebind_btn)
		
		_action_labels[action] = binding_label
		
		actions_container.add_child(row_container)

func _update_binding_label(label: Label, action: String, player_slot: int) -> void:
	"""Update the binding display for an action."""
	if not label or not input_settings:
		return
	
	var binding_text = "Not bound"
	if input_settings.has_method("get_action_binding_text"):
		binding_text = input_settings.get_action_binding_text(action, player_slot)
	label.text = binding_text

func _update_controller_info() -> void:
	"""Update the controller connection status display."""
	if not controller_info_label or not input_settings:
		return
	
	var p1_name = "Not Connected"
	var p2_name = "Not Connected"
	
	if input_settings.has_method("get_gamepad_name"):
		p1_name = input_settings.get_gamepad_name(0)
		p2_name = input_settings.get_gamepad_name(1)
	
	controller_info_label.text = "P1: %s | P2: %s" % [p1_name, p2_name]

func _on_gamepad_changed(player_slot: int, device_id: int) -> void:
	"""Called when a gamepad is connected or disconnected."""
	_update_controller_info()

func _on_rebind_pressed(action: String) -> void:
	"""Start listening for new input to bind to an action."""
	_listening_action = action
	
	if listening_label:
		var action_display = action
		if input_settings and input_settings.has_method("get_action_display_name"):
			action_display = input_settings.get_action_display_name(action)
		listening_label.text = "Press a gamepad button for '%s'..." % action_display
		listening_label.visible = true
	
	_set_listening_mode(true)
	set_process_input(true)

func _set_listening_mode(listening: bool) -> void:
	"""Update UI to show/hide listening mode."""
	for row in actions_container.get_children():
		for child in row.get_children():
			if child is Button:
				child.disabled = listening

func _input(event: InputEvent) -> void:
	"""Handle input events for rebinding."""
	if _listening_action == "":
		return
	
	if event == null:
		return
	
	# Only process pressed events (not released)
	if event is InputEventJoypadButton and not event.is_pressed():
		return
	if event is InputEventJoypadMotion:
		var abs_value = abs(event.get_axis_value())
		if abs_value < 0.5:
			return
	
	# Only accept gamepad events (no keyboard)
	if event is InputEventKey:
		if event.get_keycode() == KEY_ESCAPE:
			_cancel_listening()
		return
	
	# Bind the gamepad event
	_bind_event(event)

func _bind_event(event: InputEvent) -> void:
	"""Bind the given event to the current listening action."""
	if _listening_action == "" or input_settings == null:
		return
	
	# Only bind gamepad events
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		_cancel_listening()
		return
	
	# Map the action to the event
	if input_settings.has_method("map_action_to_event"):
		input_settings.map_action_to_event(_listening_action, event)
	
	# Save the bindings
	if input_settings.has_method("save_bindings"):
		input_settings.save_bindings()
	
	_cancel_listening()

func _cancel_listening() -> void:
	"""Cancel the listening mode."""
	_listening_action = ""
	
	if listening_label:
		listening_label.visible = false
	
	_set_listening_mode(false)
	set_process_input(false)

func _on_binding_changed(action: String, event: InputEvent) -> void:
	"""Called when a binding is changed."""
	if action in _action_labels:
		var label = _action_labels[action]
		if label:
			# Determine player slot from action
			var player_slot = 0
			if input_settings:
				var category = input_settings.get_action_category(action) if input_settings.has_method("get_action_category") else ""
				if category == "player2":
					player_slot = 1
			_update_binding_label(label, action, player_slot)

func _on_reset_pressed() -> void:
	"""Reset all bindings to defaults."""
	if input_settings and input_settings.has_method("reset_to_defaults"):
		input_settings.reset_to_defaults()
	
	for action in _action_labels:
		var label = _action_labels[action]
		if label:
			var player_slot = 0
			if input_settings:
				var category = input_settings.get_action_category(action) if input_settings.has_method("get_action_category") else ""
				if category == "player2":
					player_slot = 1
			_update_binding_label(label, action, player_slot)

func _on_save_pressed() -> void:
	"""Save bindings and close."""
	if input_settings and input_settings.has_method("save_bindings"):
		input_settings.save_bindings()
	
	queue_free()

func _on_back_pressed() -> void:
	"""Close without saving (bindings are auto-saved on change)."""
	queue_free()
