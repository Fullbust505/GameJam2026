extends Button

@export var player: String = "p1"
@export var action: String = "move_up"

func _ready():
	KeybindManager.binding_complete.connect(_on_binding_complete)
	KeybindManager.binding_duplicate.connect(_on_binding_duplicate)
	update_display()

func _pressed():
	KeybindManager.start_rebinding(action, player)
	text = "..."
	disabled = true

func _on_binding_complete(action_name: String, player_name: String):
	if action_name == action and player_name == player:
		update_display()
		disabled = false

func _on_binding_duplicate():
	update_display()
	disabled = false

func update_display():
	text = ConfigManager.get_binding_display(player, action)
