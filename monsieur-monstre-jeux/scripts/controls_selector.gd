extends CanvasLayer
class_name ControlsSelector

# Alternative Controls UI for players without legs
# Allows players to select their preferred control scheme

signal scheme_selected(player_index: int, scheme: int)

enum ControlScheme {
	BREATH_ONLY,    # For apnea minigame - breath control
	JOYSTICK_ONLY,  # For swimming - movement only
	BUTTONS_ONLY,   # For cutting - button presses
	HYBRID          # Combination of controls
}

const LEGS_ORGAN_TYPE: int = 4  # From game_state.gd OrganType.LEGS = 4

const SCHEME_DISPLAY_NAMES: Dictionary = {
	ControlScheme.BREATH_ONLY: "Breath Only",
	ControlScheme.JOYSTICK_ONLY: "Joystick Only",
	ControlScheme.BUTTONS_ONLY: "Buttons Only",
	ControlScheme.HYBRID: "Hybrid"
}

const SCHEME_DESCRIPTIONS: Dictionary = {
	ControlScheme.BREATH_ONLY: "Control using breath/blowing. Ideal for apnea challenges.",
	ControlScheme.JOYSTICK_ONLY: "Control using joystick/d-pad movement only.",
	ControlScheme.BUTTONS_ONLY: "Control using button presses for timing challenges.",
	ControlScheme.HYBRID: "Use a combination of controls depending on the minigame."
}

const SCHEME_ICONS: Dictionary = {
	ControlScheme.BREATH_ONLY: "B",
	ControlScheme.JOYSTICK_ONLY: "J",
	ControlScheme.BUTTONS_ONLY: "X",
	ControlScheme.HYBRID: "H"
}

var _current_player_index: int = -1
var _selected_scheme: int = ControlScheme.HYBRID
var _session_selections: Dictionary = {}  # player_index -> scheme
var _is_visible: bool = false

@onready var panel: PanelContainer = $PanelContainer
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var description_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DescriptionLabel
@onready var options_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/OptionsContainer
@onready var missing_organs_label: Label = $PanelContainer/MarginContainer/VBoxContainer/MissingOrgansLabel
@onready var confirm_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/ConfirmButton
@onready var skip_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/SkipButton

var _option_buttons: Array = []
var _game_state: Node = null
var _animations: Node = null

func _ready() -> void:
	# Get animations helper
	_animations = get_node_or_null("/root/Animations")
	
	panel.visible = false
	_set_game_state_reference()
	_create_option_buttons()
	_connect_signals()

func _set_game_state_reference() -> void:
	# Find GameState in the tree
	if get_tree().has_group("GameState"):
		_game_state = get_tree().get_first_node_in_group("GameState")
	else:
		# Try to find it as an autoload
		if Engine.has_singleton("GameState"):
			_game_state = Engine.get_singleton("GameState")

func _create_option_buttons() -> void:
	# Clear existing buttons
	for btn in _option_buttons:
		if is_instance_valid(btn.get("button")):
			btn.get("button").queue_free()
	_option_buttons.clear()
	
	# Create button for each control scheme
	for scheme_name in ControlScheme.keys():
		var scheme_int: int = ControlScheme.get(scheme_name)
		var btn: Button = Button.new()
		btn.text = "[%s] %s" % [SCHEME_ICONS.get(scheme_int, "*"), SCHEME_DISPLAY_NAMES.get(scheme_int, scheme_name)]
		btn.pressed.connect(_on_option_selected.bind(scheme_int))
		btn.custom_minimum_size.y = 50
		options_container.add_child(btn)
		_option_buttons.append({ "button": btn, "scheme": scheme_int })

func _connect_signals() -> void:
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)

func _on_option_selected(scheme: int) -> void:
	_selected_scheme = scheme
	_update_option_appearances()
	_update_description(scheme)

func _update_option_appearances() -> void:
	for option_data in _option_buttons:
		var btn: Button = option_data.get("button")
		if not is_instance_valid(btn):
			continue
		var is_selected: bool = (option_data.get("scheme") == _selected_scheme)
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_selected else Color(0.6, 0.6, 0.6, 1.0)

func _update_description(scheme: int) -> void:
	if description_label:
		description_label.text = SCHEME_DESCRIPTIONS.get(scheme, "")

func show_selector(player_index: int) -> void:
	_current_player_index = player_index
	
	# Check if player has legs - if they do and already have a selection, skip
	if _player_has_legs(player_index) and _session_selections.has(player_index):
		_selected_scheme = _session_selections[player_index]
		emit_signal("scheme_selected", player_index, _selected_scheme)
		return
	
	# Check for existing session selection
	if _session_selections.has(player_index):
		_selected_scheme = _session_selections[player_index]
	else:
		_selected_scheme = ControlScheme.HYBRID
	
	# Update UI
	_update_player_info()
	_update_option_appearances()
	_update_description(_selected_scheme)
	
	# Show with animation
	panel.visible = true
	_is_visible = true
	
	# Slide in animation
	if _animations:
		_animations.slide_in_top(panel, 0.4)
	
	# Set mouse filters to allow interaction
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

func hide_selector() -> void:
	# Slide out animation before hiding
	if _animations:
		_animations.slide_out_top(panel, 0.3)
		await get_tree().create_timer(0.35).timeout
	
	panel.visible = false
	_is_visible = false
	_current_player_index = -1
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _update_player_info() -> void:
	if title_label:
		title_label.text = "Player %d - Select Control Scheme" % (_current_player_index + 1)
	
	if missing_organs_label:
		var missing: Array = _get_missing_organs(_current_player_index)
		if missing.size() > 0:
			var organ_names: Array = []
			for organ_type in missing:
				organ_names.append(_get_organ_display_name(organ_type))
			missing_organs_label.text = "Missing: %s" % ", ".join(organ_names)
			missing_organs_label.visible = true
		else:
			missing_organs_label.visible = false

func _get_missing_organs(player_index: int) -> Array:
	var missing: Array = []
	
	if not _game_state:
		return missing
	
	var player = _get_player_state(player_index)
	if not player:
		return missing
	
	# Check for LEGS specifically (the main concern for controls)
	if player.get_organ_count(LEGS_ORGAN_TYPE) <= 0:
		missing.append(LEGS_ORGAN_TYPE)
	
	return missing

func _get_player_state(player_index: int):
	if _game_state and "players" in _game_state:
		var players: Array = _game_state.players
		if player_index < players.size():
			return players[player_index]
	return null

func _player_has_legs(player_index: int) -> bool:
	if not _game_state:
		return true  # Default to true if can't determine
	
	var player = _get_player_state(player_index)
	if player:
		return player.get_organ_count(LEGS_ORGAN_TYPE) > 0
	return true

func _get_organ_display_name(organ_type: int) -> String:
	if _game_state and _game_state.has_method("get_organ_name"):
		return _game_state.get_organ_name(organ_type)
	# Fallback display names for common organs
	var fallback_names: Dictionary = {
		0: "Heart", 1: "Lungs", 2: "Eyes", 3: "Legs", 4: "Hands",
		5: "Stomach", 6: "Brain", 7: "Pancreas", 8: "Liver", 9: "Kidneys"
	}
	if fallback_names.has(organ_type):
		return fallback_names[organ_type]
	return "Organ %d" % organ_type

func _on_confirm_pressed() -> void:
	_session_selections[_current_player_index] = _selected_scheme
	emit_signal("scheme_selected", _current_player_index, _selected_scheme)
	hide_selector()

func _on_skip_pressed() -> void:
	# Use hybrid as default when skipped
	_session_selections[_current_player_index] = ControlScheme.HYBRID
	emit_signal("scheme_selected", _current_player_index, ControlScheme.HYBRID)
	hide_selector()

func get_selected_scheme() -> int:
	return _selected_scheme

func get_session_scheme(player_index: int) -> int:
	if _session_selections.has(player_index):
		return _session_selections[player_index]
	return ControlScheme.HYBRID  # Default

func has_selection(player_index: int) -> bool:
	return _session_selections.has(player_index)

func clear_session_selections() -> void:
	_session_selections.clear()

func needs_selector(player_index: int) -> bool:
	"""Check if player needs to see the control selector"""
	# If player has no legs and no saved selection, they need the selector
	if not _player_has_legs(player_index) and not _session_selections.has(player_index):
		return true
	return false

func player_needs_alternative_controls(player_index: int) -> bool:
	"""Returns true if player has 0 legs and needs alternative control scheme"""
	return not _player_has_legs(player_index)
