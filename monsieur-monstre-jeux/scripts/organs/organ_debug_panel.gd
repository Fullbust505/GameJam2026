extends Control

## Debug panel to test organ quirks with VISUAL FEEDBACK.

var organ_manager: OrganManager
var brain_retrieval: BrainRetrieval

var player_index: int = 0
var organ_buttons = {}
var organ_button_order = ["Heart", "Liver", "Pancreas", "Mouth", "Eyes", "Arms", "Legs"]
var event_log = []
var last_log_size = 0
var tutorial_shown = {}

# Gamepad navigation
var selected_button_index = 0
var last_dpad_y = 0.0
var last_a_pressed = false
var last_b_pressed = false

# Visual effect nodes
var crash_overlay: ColorRect
var crash_progress: ProgressBar
var crash_label: Label
var blur_overlay: ColorRect
var blur_label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(400, 700)
	position = Vector2(10, 10)

	organ_manager = OrganManager.new()
	brain_retrieval = BrainRetrieval.new()
	add_child(organ_manager)
	add_child(brain_retrieval)

	organ_manager.set_player_index(player_index)
	_connect_organ_signals()
	_build_debug_ui()
	_create_visual_effects()
	_update_button_highlight()

	
func _create_visual_effects() -> void:
	# Crash overlay (needs to be ColorRect to have color)
	crash_overlay = ColorRect.new()
	crash_overlay.name = "CrashOverlay"
	crash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	crash_overlay.color = Color(0.5, 0, 0, 0)
	crash_overlay.visible = false
	add_child(crash_overlay)

	var crash_vbox = VBoxContainer.new()
	crash_vbox.set_anchors_preset(Control.PRESET_CENTER)
	crash_overlay.add_child(crash_vbox)

	crash_label = Label.new()
	crash_label.name = "CrashLabel"
	crash_label.text = "SUGAR CRASH!\nTap A rapidly!"
	crash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crash_label.add_theme_font_size_override("font_size", 24)
	crash_vbox.add_child(crash_label)

	crash_progress = ProgressBar.new()
	crash_progress.name = "CrashProgress"
	crash_progress.custom_minimum_size = Vector2(300, 30)
	crash_progress.max_value = 12
	crash_progress.value = 0
	crash_progress.show_percentage = false
	crash_vbox.add_child(crash_progress)

	# Blur overlay
	blur_overlay = ColorRect.new()
	blur_overlay.name = "BlurOverlay"
	blur_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	blur_overlay.color = Color(0, 0, 0.1, 0)
	add_child(blur_overlay)

	blur_label = Label.new()
	blur_label.name = "BlurLabel"
	blur_label.set_anchors_preset(Control.PRESET_CENTER)
	blur_label.text = ""
	blur_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blur_label.add_theme_font_size_override("font_size", 20)
	add_child(blur_label)

func _connect_organ_signals() -> void:
	if not organ_manager:
		return

	if organ_manager.heart:
		organ_manager.heart.pump_completed.connect(_on_pump_completed)
		organ_manager.heart.consciousness_lost.connect(_on_consciousness_lost)

	if organ_manager.liver:
		organ_manager.liver.toxin_level_changed.connect(_on_toxin_changed)
		organ_manager.liver.drunk_logic_activated.connect(_on_drunk_activated)
		organ_manager.liver.drunk_logic_deactivated.connect(_on_drunk_deactivated)

	if organ_manager.pancreas:
		organ_manager.pancreas.crash_started.connect(_on_crash_started)
		organ_manager.pancreas.crash_recovered.connect(_on_crash_recovered)

	if organ_manager.mouth:
		organ_manager.mouth.cough_started.connect(_on_cough_started)
		organ_manager.mouth.choke_started.connect(_on_choke_started)

	if organ_manager.eyes:
		organ_manager.eyes.blur_level_changed.connect(_on_blur_changed)

	if organ_manager.arms:
		organ_manager.arms.tremor_activated.connect(_on_arms_tremor)

	if organ_manager.legs:
		organ_manager.legs.leg_drag_started.connect(_on_leg_drag)

# Signal handlers
func _on_pump_completed(perfect: bool) -> void:
	var text = "> HEART PUMP " + ("OK" if perfect else "MISS")
	_add_event(text, Color.GREEN if perfect else Color.ORANGE)

func _on_consciousness_lost() -> void:
	_add_event("> BLACKOUT! 3 pumps missed", Color.RED)
	_show_screen_flash(Color(0.5, 0, 0, 0.7))

func _on_toxin_changed(level: float) -> void:
	if int(level) % 20 == 0 and level > 0:
		_add_event("> TOXIN: " + str(int(level)) + "%", Color.GREEN.darkened(level/100))

func _on_drunk_activated() -> void:
	_add_event("> DRUNK! Controls mirrored!", Color.ORANGE)

func _on_drunk_deactivated() -> void:
	_add_event("> SOBER! Controls normal", Color.GREEN)

func _on_crash_started() -> void:
	_add_event("> SUGAR CRASH! Tap A rapidly!", Color.RED)
	_add_event("> 12 pumps in 8sec or BLACKOUT!", Color.YELLOW)
	_show_crash_overlay(true)

func _on_crash_recovered() -> void:
	_add_event("> SUGAR STABILIZED!", Color.GREEN)
	_show_crash_overlay(false)

func _on_cough_started() -> void:
	_add_event("> COUGHING! Tap B to suppress", Color.CYAN)

func _on_choke_started() -> void:
	_add_event("> CHOKING! Hold B+X rapidly!", Color.RED)

func _on_blur_changed(level: float) -> void:
	if int(level) % 15 == 0 and level > 0:
		_add_event("> BLUR: " + str(int(level)) + "%", Color.PURPLE)
	_update_blur_effect(level)

func _on_arms_tremor() -> void:
	_add_event("> ARM TREMBLE! Hold LT to steady", Color.ORANGE)

func _on_leg_drag() -> void:
	_add_event("> LEG GAVE OUT! Alternate A+B!", Color.YELLOW)

func _show_crash_overlay(should_show: bool) -> void:
	if crash_overlay:
		crash_overlay.visible = should_show
	if should_show:
		_show_screen_flash(Color(0.8, 0.2, 0, 0.6))

func _update_blur_effect(level: float) -> void:
	if blur_overlay:
		var darkness = (level / 100.0) * 0.7
		blur_overlay.color = Color(0, 0, 0.1, darkness)
	if blur_label:
		if level > 50:
			blur_label.text = "VISION BLURRED: " + str(int(level)) + "%"
			blur_label.add_theme_color_override("font_color", Color.WHITE)
		else:
			blur_label.text = ""

var screen_flash: ColorRect

func _show_screen_flash(color: Color) -> void:
	if not screen_flash:
		screen_flash = ColorRect.new()
		screen_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		screen_flash.color = Color(0, 0, 0, 0)
		add_child(screen_flash)

	screen_flash.color = color
	screen_flash.modulate = Color.WHITE

	var tween = create_tween()
	tween.tween_property(screen_flash, "modulate", Color(1, 1, 1, 0), 0.5)

func _add_event(text: String, color: Color) -> void:
	event_log.append({"text": text, "color": color, "time": 3.0})
	if event_log.size() > 12:
		event_log.remove_at(0)

func _build_debug_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.1, 0.1, 0.15, 0.95)
	add_child(bg)

	# Main container
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	vbox.custom_minimum_size = Vector2(380, 0)
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Title
	var title = Label.new()
	title.name = "Title"
	title.text = "ORGAN DEBUG"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	# Close button
	var close_btn = Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "X (close)"
	close_btn.custom_minimum_size = Vector2(60, 25)
	close_btn.pressed.connect(func(): visible = false)
	vbox.add_child(close_btn)

	# Organ buttons
	var organ_names = ["Heart", "Liver", "Pancreas", "Mouth", "Eyes", "Arms", "Legs"]
	var hbox = HBoxContainer.new()
	hbox.name = "OrganButtons"
	for organ_name in organ_names:
		var btn = Button.new()
		btn.name = organ_name + "_Btn"
		btn.text = organ_name.substr(0, 3).to_upper()
		btn.custom_minimum_size = Vector2(50, 40)
		btn.add_theme_color_override("normal", Color.GREEN)
		btn.add_theme_color_override("hover", Color(0.7, 1, 0.7))
		btn.pressed.connect(_on_organ_toggle.bind(organ_name, btn))
		hbox.add_child(btn)
		organ_buttons[organ_name] = btn
	vbox.add_child(hbox)

	# Brain buttons
	var brain_hbox = HBoxContainer.new()
	var test_lose_btn = Button.new()
	test_lose_btn.text = "LOSE RANDOM"
	test_lose_btn.custom_minimum_size = Vector2(110, 35)
	test_lose_btn.add_theme_color_override("normal", Color.RED)
	test_lose_btn.pressed.connect(_on_test_lose_organ)
	brain_hbox.add_child(test_lose_btn)

	var revive_btn = Button.new()
	revive_btn.text = "RESTORE"
	revive_btn.custom_minimum_size = Vector2(90, 35)
	revive_btn.add_theme_color_override("normal", Color.GREEN)
	revive_btn.pressed.connect(_on_revive)
	brain_hbox.add_child(revive_btn)
	vbox.add_child(brain_hbox)

	# Tutorial box
	var tutorial_box = PanelContainer.new()
	tutorial_box.name = "TutorialBox"
	tutorial_box.visible = false
	tutorial_box.custom_minimum_size = Vector2(360, 100)
	vbox.add_child(tutorial_box)

	var tutorial_bg = ColorRect.new()
	tutorial_bg.color = Color(0.2, 0.2, 0.3, 0.95)
	tutorial_box.add_child(tutorial_bg)

	var tutorial_vbox = VBoxContainer.new()
	tutorial_vbox.name = "TutorialVBox"
	tutorial_box.add_child(tutorial_vbox)

	var tutorial_title = Label.new()
	tutorial_title.name = "TutorialTitle"
	tutorial_title.text = "ORGAN LOST!"
	tutorial_title.add_theme_color_override("font_color", Color.RED)
	tutorial_title.add_theme_font_size_override("font_size", 14)
	tutorial_vbox.add_child(tutorial_title)

	var tutorial_desc = Label.new()
	tutorial_desc.name = "TutorialDesc"
	tutorial_desc.text = "You have ONE turn to retrieve it."
	tutorial_vbox.add_child(tutorial_desc)

	# Event log
	var log_title = Label.new()
	log_title.text = "\n--- EVENT LOG ---"
	log_title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(log_title)

	var log_scroll = ScrollContainer.new()
	log_scroll.name = "LogScroll"
	log_scroll.custom_minimum_size = Vector2(360, 120)
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(log_scroll)

	var log_label = RichTextLabel.new()
	log_label.name = "EventLog"
	log_label.custom_minimum_size = Vector2(340, 120)
	log_label.bbcode_enabled = true
	log_label.text = "[color=gray]Press organ buttons above to test[/color]"
	log_scroll.add_child(log_label)

	# Status
	var status_title = Label.new()
	status_title.text = "\n--- STATUS ---"
	status_title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(status_title)

	var status_scroll = ScrollContainer.new()
	status_scroll.name = "StatusScroll"
	status_scroll.custom_minimum_size = Vector2(360, 180)
	status_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(status_scroll)

	var status_text = TextEdit.new()
	status_text.name = "StatusDisplay"
	status_text.editable = false
	status_text.custom_minimum_size = Vector2(340, 180)
	status_text.text = "Click organ buttons above"
	status_scroll.add_child(status_text)

func _show_tutorial(organ_name: String) -> void:
	if tutorial_shown.get(organ_name, false):
		return
	tutorial_shown[organ_name] = true

	var vbox = find_child("VBoxContainer", true, false)
	if not vbox:
		return

	var tutorial_box = vbox.find_child("TutorialBox", true, false)
	if not tutorial_box:
		return

	var explanations = {
		"heart": "Tap A rapidly to pump blood.\nMiss 3x = blackout!",
		"liver": "DON'T PRESS ANYTHING to detox!\nAny input = more toxin.\nX = antidote shot.",
		"pancreas": "Sugar crash = BLACKOUT QTE!\nTap A rapidly to recover.\n12 pumps in 8 sec or die!",
		"mouth": "Hold B = hold breath.\nTap B fast = hyperventilate.\nB+X = stop choking.",
		"eyes": "Vision blurs more over time!\nRS click = echo ping (less blur).\nLook at peripheral ghosts.",
		"arms": "LT = steady hands (slow).\nLB/RB = switch hands.\nA+X = power throw.",
		"legs": "A hold = crawl.\nA+B = sprint burst.\nAlternate A+B if leg drags."
	}

	tutorial_box.visible = true
	var tutorial_vbox = tutorial_box.find_child("TutorialVBox", true, false)
	if tutorial_vbox:
		var desc = tutorial_vbox.find_child("TutorialDesc", true, false)
		if desc:
			desc.text = explanations.get(organ_name, "Unknown organ!")

	await get_tree().create_timer(5.0).timeout
	tutorial_box.visible = false

func _on_organ_toggle(organ_name: String, btn: Button) -> void:
	if not organ_manager:
		return

	var is_missing = false
	match organ_name.to_lower():
		"heart": is_missing = organ_manager.heart.is_missing
		"liver": is_missing = organ_manager.liver.is_missing
		"pancreas": is_missing = organ_manager.pancreas.is_missing
		"mouth": is_missing = organ_manager.mouth.is_missing
		"eyes": is_missing = organ_manager.eyes.is_missing
		"arms": is_missing = organ_manager.arms.is_missing
		"legs": is_missing = organ_manager.legs.is_missing

	var new_missing = not is_missing
	organ_manager.set_organ_missing(organ_name, new_missing)

	if new_missing:
		organ_manager.activate_organ(organ_name)
		_show_tutorial(organ_name)
		_add_event("> " + organ_name.to_upper() + " MISSING!", Color.RED)
	else:
		_add_event("> " + organ_name.to_upper() + " restored", Color.GREEN)
		if organ_name == "pancreas":
			_show_crash_overlay(false)
		if organ_name == "eyes":
			_update_blur_effect(0)

	if new_missing:
		btn.text = organ_name.substr(0, 3).to_upper() + "!"
		btn.add_theme_color_override("normal", Color.RED)
	else:
		btn.text = organ_name.substr(0, 3).to_upper()
		btn.add_theme_color_override("normal", Color.GREEN)

func _on_test_lose_organ() -> void:
	if not organ_manager:
		return

	var organs = ["heart", "liver", "pancreas", "mouth", "eyes", "arms", "legs"]
	var random_organ = organs[randi() % organs.size()]
	organ_manager.set_organ_missing(random_organ, true)
	organ_manager.activate_organ(random_organ)

	_show_tutorial(random_organ)
	_add_event("> LOST " + random_organ.to_upper() + "!", Color.RED)
	_add_event("> ONE TURN to retrieve!", Color.YELLOW)

	if brain_retrieval:
		brain_retrieval.start_retrieval(random_organ)

	var btn = organ_buttons.get(random_organ.capitalize())
	if btn:
		btn.text = random_organ.substr(0, 3).to_upper() + "!"
		btn.add_theme_color_override("normal", Color.RED)

func _on_revive() -> void:
	if brain_retrieval:
		brain_retrieval.revive_player()

	for organ_name in organ_buttons:
		var btn = organ_buttons[organ_name]
		btn.text = organ_name.substr(0, 3).to_upper()
		btn.add_theme_color_override("normal", Color.GREEN)

	_show_crash_overlay(false)
	_update_blur_effect(0)
	_add_event("> ALL ORGANS RESTORED!", Color.GREEN)
	event_log.clear()
	tutorial_shown.clear()

	var vbox = find_child("VBoxContainer", true, false)
	if vbox:
		var tutorial_box = vbox.find_child("TutorialBox", true, false)
		if tutorial_box:
			tutorial_box.visible = false

func _process(delta: float) -> void:
	if organ_manager:
		organ_manager._process(delta)
	else:
		# Try to reconnect
		organ_manager = get_parent() as OrganManager
		if organ_manager:
			organ_manager.set_player_index(player_index)
			_connect_organ_signals()
	_update_status_display()
	_update_event_log()
	_update_crash_display()

func _update_crash_display() -> void:
	if organ_manager and organ_manager.is_in_crash_qte():
		var pumps = organ_manager.get_crash_pumps()
		if crash_progress:
			crash_progress.value = pumps
		if crash_label:
			crash_label.text = "SUGAR CRASH!\nPumps: %d/12" % pumps

func _update_event_log() -> void:
	if event_log.size() == last_log_size:
		return
	last_log_size = event_log.size()

	var vbox = find_child("VBoxContainer", true, false)
	if not vbox:
		return

	var log_scroll = vbox.find_child("LogScroll", true, false)
	var log_label = vbox.find_child("EventLog", true, false)
	if not log_label or not log_label is RichTextLabel:
		return

	var text = ""
	for event in event_log:
		var color_name = "gray"
		match event["color"]:
			Color.RED: color_name = "red"
			Color.YELLOW: color_name = "yellow"
			Color.CYAN: color_name = "cyan"
			Color.ORANGE: color_name = "orange"
			Color.PURPLE: color_name = "purple"
			Color.GREEN: color_name = "green"
		text += "[color=" + color_name + "]" + event["text"] + "[/color]\n"

	if text == "":
		text = "[color=gray]Click organ buttons above to test[/color]"

	log_label.text = text

	if log_scroll:
		log_scroll.set_v_scroll(log_scroll.get_v_scroll_bar().max_value)

func _update_status_display() -> void:
	var vbox = find_child("VBoxContainer", true, false)
	if not vbox:
		return

	var status_scroll = vbox.find_child("StatusScroll", true, false)
	var status_text = vbox.find_child("StatusDisplay", true, false)
	if not status_text or not status_text is TextEdit:
		return

	if not organ_manager:
		status_text.text = "No OrganManager found!"
		return

	var all_status = organ_manager.get_all_status()
	var brain_status = {"is_alive": true, "is_retrieval_active": false, "current_organ": "", "remaining_time": 0.0}
	if brain_retrieval and brain_retrieval.get_status:
		brain_status = brain_retrieval.get_status()

	var text = ""
	for organ_name in ["heart", "liver", "pancreas", "mouth", "eyes", "arms", "legs"]:
		var status = all_status[organ_name]
		var missing = status["is_missing"]
		text += organ_name.capitalize() + ": " + ("MISSING" if missing else "OK") + "\n"

		if missing:
			if organ_name == "pancreas" and status.get("is_crashing", false):
				var pumps = status.get("pumps_during_crash", 0)
				var required = status.get("pumps_required", 12)
				text += "  CRASH! Pumps: %d/%d\n" % [pumps, required]
			elif organ_name == "eyes":
				var blur = status.get("blur_level", 0.0)
				text += "  Blur: %.0f%%\n" % blur
			else:
				var active_quirks = []
				for key in status.keys():
					if key != "organ_name" and key != "is_missing" and status[key] != null:
						var val = status[key]
						if typeof(val) == TYPE_BOOL and val:
							active_quirks.append(key)
						elif typeof(val) == TYPE_FLOAT and val != 0.0 and val != 1.0:
							active_quirks.append(key + ":%.0f" % val)
				if active_quirks.size() > 0:
					text += "  " + ", ".join(active_quirks) + "\n"

	text += "\nBrain: " + ("ALIVE" if brain_status["is_alive"] else "DEAD")
	if brain_status["is_retrieval_active"]:
		text += " | RETRIEVAL: " + brain_status["current_organ"].to_upper() + " (%.1fs)" % brain_status["remaining_time"]

	status_text.text = text

	if status_scroll:
		status_scroll.set_v_scroll(status_scroll.get_v_scroll_bar().max_value)
		
func _input(event: InputEvent) -> void:
	# F1 to toggle visibility
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		visible = not visible

	# Gamepad navigation with D-pad (player 0)
	var dpad_y = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)

	# D-pad up/down to navigate buttons
	if dpad_y < -0.5 and last_dpad_y > -0.5:
		selected_button_index = wrapi(selected_button_index - 1, 0, organ_button_order.size())
		_update_button_highlight()
	elif dpad_y > 0.5 and last_dpad_y < 0.5:
		selected_button_index = wrapi(selected_button_index + 1, 0, organ_button_order.size())
		_update_button_highlight()

	last_dpad_y = dpad_y

	# A button (0) to press selected button - edge trigger on press
	var a_pressed = Input.is_joy_button_pressed(0, JOY_BUTTON_A)
	if a_pressed and not last_a_pressed:
		var organ_name = organ_button_order[selected_button_index]
		var btn = organ_buttons.get(organ_name)
		if btn:
			btn.emit_signal("pressed")
	last_a_pressed = a_pressed

	# B button (1) to close panel - edge trigger on press
	var b_pressed = Input.is_joy_button_pressed(0, JOY_BUTTON_B)
	if b_pressed and not last_b_pressed:
		visible = false
	last_b_pressed = b_pressed

func _update_button_highlight() -> void:
	for i in range(organ_button_order.size()):
		var organ_name = organ_button_order[i]
		var btn = organ_buttons.get(organ_name)
		if btn:
			if i == selected_button_index:
				btn.add_theme_color_override("normal", Color.YELLOW)
			else:
				var is_missing = false
				match organ_name.to_lower():
					"heart": is_missing = organ_manager.heart.is_missing
					"liver": is_missing = organ_manager.liver.is_missing
					"pancreas": is_missing = organ_manager.pancreas.is_missing
					"mouth": is_missing = organ_manager.mouth.is_missing
					"eyes": is_missing = organ_manager.eyes.is_missing
					"arms": is_missing = organ_manager.arms.is_missing
					"legs": is_missing = organ_manager.legs.is_missing
				btn.add_theme_color_override("normal", Color.RED if is_missing else Color.GREEN)
