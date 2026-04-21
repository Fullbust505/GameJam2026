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
	ControlScheme.BREATH_ONLY: "💨",
	ControlScheme.JOYSTICK_ONLY: "🕹️",
	ControlScheme.BUTTONS_ONLY: "🔘",
	ControlScheme.HYBRID: "🔀"
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

func _ready() -> void:
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
		if is_instance_valid(btn):
			btn.queue_free()
	_option_buttons.clear()
	
	# Create button for each control scheme
	for scheme in ControlScheme.keys():
		var scheme_int: int = ControlScheme.get(scheme)
		var btn: Button = Button.new()
		btn.text = "%s %s" % [SCHEME_ICONS.get(scheme_int, "•"), SCHEME_DISPLAY_NAMES.get(scheme_int, scheme)]
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
		var btn: Button = option_data["button"]
		var is_selected: bool = (option_data["scheme"] == _selected_scheme)
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_selected else Color(0.6, 0.6, 0.6, 1.0)
		btn.add_theme_stylebox_override("normal", _get_stylebox_for_selection(is_selected))

func _get_stylebox_for_selection(selected: bool) -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.6, 0.2, 0.8) if selected else Color(0.3, 0.3, 0.3, 0.8)
	style.set_border_width_all(2)
	style.border_color = Color(0.4, 0.9, 0.4, 1.0) if selected else Color(0.5, 0.5, 0.5, 0.5)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	return style

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
	
	# Show the panel
	panel.visible = true
	_is_visible = true
	
	# Set mouse filters to allow interaction
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

func hide_selector() -> void:
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
			missing_organs_label.text = "Missing organs: %s" % ", ".join(organ_names)
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
	if player.get_organ_count(_get_legs_organ_type()) <= 0:
		missing.append(_get_legs_organ_type())
	
	# Could add checks for other organs relevant to controls here
	# (e.g., ARMS for button pressing)
	
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
		return player.get_organ_count(_get_legs_organ_type()) > 0
	return true

func _get_legs_organ_type() -> int:
	# Try to get LEGS from GameState.OrganType first
	if _game_state and "OrganType" in _game_state:
		return _game_state.OrganType.LEGS
	# Fallback to organ_constants
	if OrganConstants:
		return OrganConstants.ORGAN_LEGS
	return 4  # Default LEGS value

func _get_organ_display_name(organ_type: int) -> String:
	if OrganConstants and OrganConstants.ORGAN_DISPLAY_NAMES.has(organ_type):
		return OrganConstants.ORGAN_DISPLAY_NAMES[organ_type]
	if _game_state and "get_organ_name" in _game_state:
		return _game_state.get_organ_name(organ_type)
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
	# If player has legs but no selection, they can skip
	if _player_has_legs(player_index) and not _session_selections.has(player_index):
		return false
	return false

# Check if a player needs alternative controls
func player_needs_alternative_controls(player_index: int) -> bool:
	"""Returns true if player has 0 legs and needs alternative control scheme"""
	return not _player_has_legs(player_index)
