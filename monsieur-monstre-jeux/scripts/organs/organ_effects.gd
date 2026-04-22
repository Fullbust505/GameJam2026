extends Node

## Visual effects layer for organ quirks.
## Shows screen-wide effects when organs trigger their quirks.

var panel: Control
var effect_label: Label
var effect_timer: float = 0.0
var current_effects = []

func _ready() -> void:
	_create_effects_ui()

func _create_effects_ui() -> void:
	# Create a fullscreen canvas layer for effects
	var canvas = CanvasLayer.new()
	canvas.name = "EffectsCanvas"
	add_child(canvas)

	# Create effects panel at bottom of screen
	panel = Control.new()
	panel.name = "EffectsPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -100
	panel.offset_bottom = 0
	panel.custom_minimum_size = Vector2(0, 80)
	canvas.add_child(panel)

	# Background
	var bg = ColorRect.new()
	bg.name = "EffectsBG"
	bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bg.color = Color(0, 0, 0, 0.8)
	panel.add_child(bg)

	# Effect text label
	effect_label = Label.new()
	effect_label.name = "EffectLabel"
	effect_label.set_anchors_preset(Control.PRESET_CENTER)
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	effect_label.text = ""
	effect_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(effect_label)

func show_effect(text: String, color: Color = Color.WHITE) -> void:
	if not effect_label:
		return

	# Add to effects list
	current_effects.append({"text": text, "color": color, "time": 3.0})

	# Update display
	_update_effect_display()

func _update_effect_display() -> void:
	if not effect_label:
		return

	var display_text = ""
	for effect in current_effects:
		var emoji = ""
		match effect["text"]:
			"HEART PUMP": emoji = "1. "
			"CONSCIOUSNESS LOST": emoji = "2. "
			"LIVER TOXIN": emoji = "3. "
			"CONTROLS MIRRORED": emoji = "4. "
			"PANCREAS CRASH": emoji = "5. "
			"BREATH LOW": emoji = "6. "
			"COUGHING": emoji = "7. "
			"CHOKING": emoji = "8. "
			"EYES TWITCH": emoji = "9. "
			"ARMS TREMOR": emoji = "10. "
			"LEG DRAG": emoji = "11. "
			"SPRINT BURST": emoji = "12. "
			_:
				emoji = "! "
		display_text += emoji + effect["text"] + "\n"

	effect_label.text = display_text
	if current_effects.size() > 0:
		effect_label.add_theme_color_override("font_color", current_effects[0]["color"])

func _process(delta: float) -> void:
	# Update effect timers
	var to_remove = []
	for i in range(current_effects.size()):
		current_effects[i]["time"] -= delta
		if current_effects[i]["time"] <= 0:
			to_remove.append(i)

	# Remove expired effects
	for i in to_remove:
		current_effects.remove_at(i)

	if current_effects.size() > 0:
		panel.offset_top = -80  # Slide up
	else:
		panel.offset_top = 0    # Slide down

	_update_effect_display()

# Static helper to show effects from anywhere
static func create_and_show(node: Node, text: String, color: Color = Color.WHITE) -> void:
	var effects = node.get_node_or_null("EffectsCanvas")
	if effects:
		effects.show_effect(text, color)
