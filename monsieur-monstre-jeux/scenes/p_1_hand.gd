extends Sprite2D
@export var player_index=0
@onready var timer = $"../mg_duration"
signal ready_p1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if timer.is_stopped() and Input.is_joy_button_pressed(player_index, JOY_BUTTON_A):
		ready_p1.emit()
