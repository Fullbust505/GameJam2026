extends Control
var rand_game = 0
var gamestate : Dictionary = {}
@onready var json_path_backup = "res://game_state_backup.json"

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if Input.is_joy_button_pressed(0, JOY_BUTTON_A) or Input.is_joy_button_pressed(1, JOY_BUTTON_A):
		rand_game = randi_range(0,10)
		if rand_game > 5:
			get_tree().change_scene_to_file("res://scenes/cam_template.tscn")
		else:
			get_tree().change_scene_to_file("res://manger/scene/manger_minigame.tscn")

func open_json(json_path):
	var file = FileAccess.open(json_path_backup, FileAccess.READ)
	var json = file.get_as_text()
	var json_object = JSON.new()
	json_object.parse(json)
	gamestate = json_object.data
	file.close()
	print(gamestate)

func write_json(gamestate):
	var file = FileAccess.open("res://game_state.json", FileAccess.WRITE)
	var json_text = JSON.stringify(gamestate, '\t')
	file.store_string(json_text)
	file.close()
