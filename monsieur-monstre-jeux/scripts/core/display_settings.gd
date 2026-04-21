extends Node

# Pixel-Perfect Display Settings System
# Manages resolution, fullscreen, and VSync for blocky pixel-art aesthetic

const CONFIG_FILE := "user://display_settings.cfg"
const DEFAULT_WIDTH := 640
const DEFAULT_HEIGHT := 360

var config: ConfigFile

var _current_width: int = DEFAULT_WIDTH
var _current_height: int = DEFAULT_HEIGHT
var _is_fullscreen: bool = false
var _vsync_enabled: bool = true

signal resolution_changed(width: int, height: int)
signal fullscreen_changed(enabled: bool)
signal vsync_changed(enabled: bool)

func _init() -> void:
	config = ConfigFile.new()
	_load_settings()

func _ready() -> void:
	_apply_display_settings()

func _load_settings() -> void:
	var err = config.load(CONFIG_FILE)
	if err == OK:
		_current_width = config.get_value("display", "width", DEFAULT_WIDTH)
		_current_height = config.get_value("display", "height", DEFAULT_HEIGHT)
		_is_fullscreen = config.get_value("display", "fullscreen", false)
		_vsync_enabled = config.get_value("display", "vsync", true)
	else:
		_current_width = DEFAULT_WIDTH
		_current_height = DEFAULT_HEIGHT
		_is_fullscreen = false
		_vsync_enabled = true

func _save_settings() -> void:
	config.set_value("display", "width", _current_width)
	config.set_value("display", "height", _current_height)
	config.set_value("display", "fullscreen", _is_fullscreen)
	config.set_value("display", "vsync", _vsync_enabled)
	config.save(CONFIG_FILE)

func _apply_display_settings() -> void:
	var window = get_window()
	
	# Apply resolution
	if not _is_fullscreen:
		window.content_scale_size = Vector2i(_current_width, _current_height)
	
	# Apply fullscreen
	window.mode = Window.MODE_FULLSCREEN if _is_fullscreen else Window.MODE_WINDOWED
	
	# Apply VSync
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if _vsync_enabled else DisplayServer.VSYNC_DISABLED
	)

func set_resolution(width: int, height: int) -> void:
	_current_width = width
	_current_height = height
	
	var window = get_window()
	if not _is_fullscreen:
		window.content_scale_size = Vector2i(width, height)
	
	_save_settings()
	resolution_changed.emit(width, height)

func get_current_resolution() -> Dictionary:
	return {"width": _current_width, "height": _current_height}

func get_available_resolutions() -> Array:
	var resolutions: Array = []
	
	# Common 16:9 resolutions for pixel-art games
	# These are safe options that work on most displays
	var common_resolutions = [
		{"width": 640, "height": 360},   # 360p - classic pixel-art resolution
		{"width": 854, "height": 480},   # 480p
		{"width": 960, "height": 540},   # 540p
		{"width": 1280, "height": 720},  # 720p - HD
		{"width": 1600, "height": 900},  # 900p
		{"width": 1920, "height": 1080}, # 1080p - Full HD
		{"width": 2560, "height": 1440},  # 1440p - QHD
		{"width": 3840, "height": 2160}, # 4K UHD
	]
	
	# Get native display resolution using screen size API
	var screen_size = DisplayServer.screen_get_size()
	
	for res in common_resolutions:
		# Only include resolutions that fit in native display
		if res["width"] <= screen_size.x and res["height"] <= screen_size.y:
			resolutions.append(res)
	
	return resolutions

func toggle_fullscreen() -> void:
	_is_fullscreen = not _is_fullscreen
	
	var window = get_window()
	window.mode = Window.MODE_FULLSCREEN if _is_fullscreen else Window.MODE_WINDOWED
	
	_save_settings()
	fullscreen_changed.emit(_is_fullscreen)

func set_fullscreen(enabled: bool) -> void:
	_is_fullscreen = enabled
	
	var window = get_window()
	window.mode = Window.MODE_FULLSCREEN if enabled else Window.MODE_WINDOWED
	
	_save_settings()
	fullscreen_changed.emit(enabled)

func is_fullscreen() -> bool:
	return _is_fullscreen

func set_vsync(enabled: bool) -> void:
	_vsync_enabled = enabled
	
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	)
	
	_save_settings()
	vsync_changed.emit(enabled)

func is_vsync_enabled() -> bool:
	return _vsync_enabled

func reset_to_defaults() -> void:
	set_resolution(DEFAULT_WIDTH, DEFAULT_HEIGHT)
	set_fullscreen(false)
	set_vsync(true)
