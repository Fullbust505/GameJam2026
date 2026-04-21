extends Node2D

@onready var PeaScene = preload("res://manger/scene/pea.tscn")

func _ready():
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var pea_count = rng.randi_range(10, 30)

	for i in range(pea_count):
		var pea = PeaScene.instantiate()

		# spawns up above
		pea.position = Vector2(
			rng.randf_range(200, 500),
			rng.randf_range(50, 100)
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
