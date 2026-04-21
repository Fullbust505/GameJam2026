extends Control

## UI controller for Extra Organ Bonus system
## Displays available bonuses and allows player to activate them

# Reference to ExtraOrganBonus system
var _bonus_system: Node = null

# Current player index
var _player_index: int = 0

# Bonus buttons for each organ
var _bonus_buttons: Dictionary = {}

# Animation helper
var _animations: Node = null

# Signals
signal bonus_selected(organ_type: int)
signal ui_closed()

func _ready() -> void:
	# Get animations helper
	_animations = get_node_or_null("/root/Animations")
	
	# Get references to children
	var close_button = $VBox/CloseButton
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Initially hidden
	set_visible(false)

## Setup with bonus system reference
func setup(bonus_system: Node) -> void:
	_bonus_system = bonus_system
	
	# Connect to bonus system signals if available
	if _bonus_system and _bonus_system.has_signal("bonus_available"):
		_bonus_system.connect("bonus_available", _on_bonus_available)

## Show the bonus UI for a specific player (with animation)
func show_bonuses(player_index: int) -> void:
	_player_index = player_index
	
	if not _bonus_system:
		push_error("ExtraOrganBonusUI: No bonus system reference!")
		return
	
	# Get available bonuses
	var bonuses = _bonus_system.get_available_bonuses_info(player_index)
	
	if bonuses.is_empty():
		# No bonuses available
		$VBox/InfoLabel.text = "No extra organ bonuses available"
		# Clear any existing buttons
		_clear_bonus_buttons()
	else:
		$VBox/InfoLabel.text = "Select a bonus to activate (one per turn)"
		_update_bonus_buttons(bonuses)
	
	# Show with animation
	if _animations:
		_animations.bounce_in(self, 0.4)
	else:
		set_visible(true)

## Update the bonus buttons based on available bonuses
func _update_bonus_buttons(bonuses: Array) -> void:
	# Clear existing buttons
	_clear_bonus_buttons()
	
	var list_container = $VBox/ScrollContainer/BonusesList
	
	for bonus in bonuses:
		var button = Button.new()
		var organ_name = bonus.get("organ_name", "Unknown")
		var name = bonus.get("name", "Bonus")
		var description = bonus.get("description", "")
		var can_activate = bonus.get("can_activate", false)
		
		button.text = organ_name + ": " + name
		button.tooltip_text = description
		button.disabled = not can_activate
		
		var organ_type = bonus.get("organ_type", -1)
		_bonus_buttons[organ_type] = button
		
		button.pressed.connect(_on_bonus_button_pressed.bind(organ_type))
		
		list_container.add_child(button)

## Clear all bonus buttons
func _clear_bonus_buttons() -> void:
	var list_container = $VBox/ScrollContainer/BonusesList
	for button in _bonus_buttons.values():
		if is_instance_valid(button):
			list_container.remove_child(button)
			button.queue_free()
	_bonus_buttons.clear()

## Handle bonus button press
func _on_bonus_button_pressed(organ_type: int) -> void:
	if _bonus_system:
		var success = _bonus_system.activate_bonus(_player_index, organ_type)
		if success:
			emit_signal("bonus_selected", organ_type)
			# Update UI to show bonus was used
			set_visible(false)

## Handle close button press
func _on_close_pressed() -> void:
	set_visible(false)
	_clear_bonus_buttons()
	emit_signal("ui_closed")

## Handle bonus available signal from bonus system
func _on_bonus_available(player_index: int, available: Array) -> void:
	if player_index == _player_index:
		show_bonuses(player_index)

## Update the UI state (e.g., when bonus was used)
func refresh() -> void:
	if _bonus_system and visible:
		show_bonuses(_player_index)

## Hide and reset (with animation)
func dismiss() -> void:
	if _animations:
		_animations.bounce_out(self, 0.25)
		await get_tree().create_timer(0.3).timeout
		set_visible(false)
	else:
		set_visible(false)
	_clear_bonus_buttons()
