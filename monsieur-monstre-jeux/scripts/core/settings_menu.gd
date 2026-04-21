extends Control

# Settings Menu Controller
# Manages display settings UI, debug settings, and game options

@onready var resolution_option: OptionButton = $Panel/VBox/ResolutionOption
@onready var fullscreen_check: CheckButton = $Panel/VBox/FullscreenCheck
@onready var vsync_check: CheckButton = $Panel/VBox/VSyncCheck
@onready var apply_button: Button = $Panel/VBox/ButtonHBox/ApplyButton
@onready var close_button: Button = $Panel/VBox/ButtonHBox/CloseButton
@onready var controls_button: Button = $Panel/VBox/ControlsButton

# Debug options - these will only show in debug builds
@onready var debug_mode_check: CheckButton = $Panel/VBox/DebugModeCheck
@onready var single_player_check: CheckButton = $Panel/VBox/DebugOptionsContainer/SinglePlayerCheck
@onready var ai_player_check: CheckButton = $Panel/VBox/DebugOptionsContainer/AIPlayerCheck
@onready var debug_options_container: VBoxContainer = $Panel/VBox/DebugOptionsContainer

var display_settings: Node
var debug_settings: Node

# Gamepad navigation
var _last_menu_action_time: Dictionary = {}
const MENU_ACTION_DEBOUNCE: float = 0.15

func _ready() -> void:
	# Get the display settings autoload
	display_settings = get_node("/root/DisplaySettings")
	
	# Get debug settings if available
	debug_settings = get_node_or_null("/root/DebugSettings")
	
	# Connect signals
	display_settings.resolution_changed.connect(_on_resolution_changed)
	display_settings.fullscreen_changed.connect(_on_fullscreen_changed)
	display_settings.vsync_changed.connect(_on_vsync_changed)
	
	# Connect UI signals
	apply_button.pressed.connect(_on_apply_pressed)
	close_button.pressed.connect(_on_close_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	
	# Connect debug settings signals if available
	if debug_settings:
		debug_settings.debug_mode_changed.connect(_on_debug_mode_changed)
		debug_settings.single_player_mode_changed.connect(_on_single_player_mode_changed)
		debug_settings.ai_player_changed.connect(_on_ai_player_changed)
		
		# Connect debug option UI signals
		if debug_mode_check:
			debug_mode_check.toggled.connect(_on_debug_mode_toggled)
			# Initialize checkbox to current debug mode state
			debug_mode_check.button_pressed = debug_settings.debug_mode
		if single_player_check:
			single_player_check.toggled.connect(_on_single_player_toggled)
			# Initialize checkbox to current single player mode state
			single_player_check.button_pressed = debug_settings.single_player_mode
		if ai_player_check:
			ai_player_check.toggled.connect(_on_ai_player_toggled)
			# Initialize checkbox to current AI player state
			ai_player_check.button_pressed = debug_settings.ai_player_enabled
	
	# Populate resolution dropdown
	_populate_resolutions()
	
	# Sync UI with current settings
	_sync_ui()
	_update_debug_visibility()

func _update_debug_visibility() -> void:
	"""Show/hide debug options based on whether we're in a debug build."""
	if debug_options_container:
		var show_debug = debug_settings and debug_settings.is_debug_build()
		debug_options_container.visible = show_debug

func _input(event: InputEvent) -> void:
	# Handle gamepad navigation
	_process_gamepad_input(event)
	
	# Handle cancel action (Esc key)
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()

func _process_gamepad_input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
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
	
	var focused = get_focused_control()
	
	match action:
		"menu_up", "menu_left":
			_move_focus(focused, -1)
		"menu_down", "menu_right":
			_move_focus(focused, 1)
		"menu_accept":
			if focused:
				if focused is Button:
					focused.emit_signal("pressed")
				elif focused is CheckButton:
					focused.toggle()
		"menu_cancel":
			_on_close_pressed()

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

func get_focused_control() -> Control:
	var vbox = $Panel/VBox
	var controls = []
	for child in vbox.get_children():
		if child is Button or child is CheckButton or child is OptionButton:
			controls.append(child)
	
	for ctrl in controls:
		if ctrl.has_focus():
			return ctrl
	return controls[0] if controls.size() > 0 else null

func _move_focus(current: Control, direction: int) -> void:
	var vbox = $Panel/VBox
	var controls = []
	for child in vbox.get_children():
		if child is Button or child is CheckButton or child is OptionButton:
			controls.append(child)
	
	if controls.size() == 0:
		return
	
	var current_idx = controls.find(current) if current else 0
	var next_idx = current_idx + direction
	if next_idx < 0:
		next_idx = controls.size() - 1
	elif next_idx >= controls.size():
		next_idx = 0
	
	controls[next_idx].grab_focus()

func _populate_resolutions() -> void:
	resolution_option.clear()
	var resolutions = display_settings.get_available_resolutions()
	var current_res = display_settings.get_current_resolution()
	var current_idx = 0
	
	for i in range(resolutions.size()):
		var res = resolutions[i]
		var label = "%dx%d" % [res["width"], res["height"]]
		resolution_option.add_item(label, i)
		
		# Track current resolution index
		if res["width"] == current_res["width"] and res["height"] == current_res["height"]:
			current_idx = i
	
	resolution_option.selected = current_idx

func _sync_ui() -> void:
	# Sync resolution dropdown
	var current_res = display_settings.get_current_resolution()
	var resolutions = display_settings.get_available_resolutions()
	for i in range(resolutions.size()):
		var res = resolutions[i]
		if res["width"] == current_res["width"] and res["height"] == current_res["height"]:
			resolution_option.selected = i
			break
	
	# Sync checkboxes
	fullscreen_check.button_pressed = display_settings.is_fullscreen()
	vsync_check.button_pressed = display_settings.is_vsync_enabled()
	
	# Sync debug options if available
	if debug_settings:
		if debug_mode_check:
			debug_mode_check.button_pressed = debug_settings.debug_mode
		if single_player_check:
			single_player_check.button_pressed = debug_settings.single_player_mode
		if ai_player_check:
			ai_player_check.button_pressed = debug_settings.ai_player_enabled

func _on_resolution_changed(width: int, height: int) -> void:
	_populate_resolutions()

func _on_fullscreen_changed(enabled: bool) -> void:
	fullscreen_check.button_pressed = enabled

func _on_vsync_changed(enabled: bool) -> void:
	vsync_check.button_pressed = enabled

func _on_debug_mode_changed(enabled: bool) -> void:
	if debug_mode_check:
		debug_mode_check.button_pressed = enabled

func _on_single_player_mode_changed(enabled: bool) -> void:
	if single_player_check:
		single_player_check.button_pressed = enabled

func _on_ai_player_changed(enabled: bool) -> void:
	if ai_player_check:
		ai_player_check.button_pressed = enabled

func _on_apply_pressed() -> void:
	# Get selected resolution
	var resolutions = display_settings.get_available_resolutions()
	var idx = resolution_option.selected
	if idx >= 0 and idx < resolutions.size():
		var res = resolutions[idx]
		display_settings.set_resolution(res["width"], res["height"])
	
	# Apply fullscreen setting
	display_settings.set_fullscreen(fullscreen_check.button_pressed)
	
	# Apply vsync setting
	display_settings.set_vsync(vsync_check.button_pressed)
	
	# Apply debug settings if available
	if debug_settings:
		if debug_mode_check:
			debug_settings.debug_mode = debug_mode_check.button_pressed
		if single_player_check:
			debug_settings.single_player_mode = single_player_check.button_pressed
		if ai_player_check:
			debug_settings.ai_player_enabled = ai_player_check.button_pressed

func _on_close_pressed() -> void:
	queue_free()

func _on_controls_pressed() -> void:
	# Open the keybind screen
	var keybind_scene = preload("res://scenes/keybind_screen.tscn")
	var keybind_instance = keybind_scene.instantiate()
	get_tree().get_current_scene().add_child(keybind_instance)

func _on_debug_mode_toggled(toggled: bool) -> void:
	if debug_settings:
		debug_settings.debug_mode = toggled

func _on_single_player_toggled(toggled: bool) -> void:
	if debug_settings:
		debug_settings.single_player_mode = toggled

func _on_ai_player_toggled(toggled: bool) -> void:
	if debug_settings:
		debug_settings.ai_player_enabled = toggled
