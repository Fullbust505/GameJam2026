extends Node

# Debug Settings Manager
# Controls debug mode functionality for testing

signal debug_mode_changed(enabled: bool)
signal single_player_mode_changed(enabled: bool)
signal ai_player_changed(enabled: bool)

const CONFIG_FILE := "user://debug_settings.cfg"
const CONFIG_SECTION := "debug"

# Debug mode - when enabled, allows keyboard fallback and single-player testing
var debug_mode: bool = false:
	set(value):
		if value != debug_mode:
			debug_mode = value
			debug_mode_changed.emit(value)
			_save_settings()

# Single player mode - P1 controls both or AI plays P2
var single_player_mode: bool = false:
	set(value):
		if value != single_player_mode:
			single_player_mode = value
			single_player_mode_changed.emit(value)
			_save_settings()

# AI controls P2
var ai_player_enabled: bool = false:
	set(value):
		if value != ai_player_enabled:
			ai_player_enabled = value
			ai_player_changed.emit(value)
			_save_settings()

# Debug overlay visibility
var debug_overlay_visible: bool = false:
	set(value):
		if value != debug_overlay_visible:
			debug_overlay_visible = value

func _ready() -> void:
	_load_settings()

func _load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_FILE)
	if err == OK:
		debug_mode = config.get_value(CONFIG_SECTION, "debug_mode", false)
		single_player_mode = config.get_value(CONFIG_SECTION, "single_player_mode", false)
		ai_player_enabled = config.get_value(CONFIG_SECTION, "ai_player_enabled", false)
	else:
		# Defaults for non-debug builds
		debug_mode = OS.has_feature("debug")
		single_player_mode = false
		ai_player_enabled = false

func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value(CONFIG_SECTION, "debug_mode", debug_mode)
	config.set_value(CONFIG_SECTION, "single_player_mode", single_player_mode)
	config.set_value(CONFIG_SECTION, "ai_player_enabled", ai_player_enabled)
	config.save(CONFIG_FILE)

func is_debug_build() -> bool:
	return OS.has_feature("debug")

func can_use_keyboard() -> bool:
	"""Returns true if keyboard input is allowed (debug mode only)."""
	return debug_mode or is_debug_build()

func toggle_debug_overlay() -> void:
	debug_overlay_visible = !debug_overlay_visible

func reset_debug_settings() -> void:
	debug_mode = is_debug_build()
	single_player_mode = false
	ai_player_enabled = false