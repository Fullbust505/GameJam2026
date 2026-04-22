extends Node2D

@onready var PeaScene = preload("res://manger/scene/pea.tscn")

signal p1_ready
signal p2_ready

func _ready():
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var pea_count = rng.randi_range(10, 30)

	for i in range(pea_count):
		var pea = PeaScene.instantiate()

		# spawns up above
		pea.position = Vector2(
			rng.randf_range(200, 400),
			rng.randf_range(100, 200)
			)

		# random rotation at spawn
		pea.rotation = rng.randf_range(0, TAU)

		# initiali_velocity
		pea.linear_velocity = Vector2(
			rng.randf_range(-25, 25),
			rng.randf_range(0, 50)
		)

		add_child(pea)
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_p_1_ready_p_1() -> void:
	p1_ready.emit()


func _on_p_2_ready_p_2() -> void:
	p2_ready.emit()
