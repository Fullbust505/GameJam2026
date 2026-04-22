extends Area2D

@onready var animation_player = $AnimationPlayer
var points = 0;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	animation_player.play("mouth_loop")


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("pea"):
		$AudioStreamPlayer.play()
		points += 1
		body.queue_free()
