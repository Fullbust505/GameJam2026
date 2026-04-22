extends Control
@onready var p1_readiness = $manger_tuto/p1readiness
@onready var p2_readiness = $manger_tuto/p2readiness
@onready var timer = $tutocd
@onready var tuto = $manger_tuto
@onready var game_timer = $Timer
@onready var mouth_p1 = $HBoxContainer/SubViewportContainer/SubViewport/MangerGameplay/Mouth
@onready var mouth_p2 = $HBoxContainer/SubViewportContainer2/SubViewport/MangerGameplay/Mouth
var p1_ready = false
var p2_ready = false

var has_started = false

var json_path = "res://game_state.json"
var json_path_backup = "res://game_state_backup.json"
var gamestate : Dictionary = {}

func _ready() -> void:
	p1_readiness.animation = "waiting"
	p2_readiness.animation = "waiting"
	timer.wait_time = 1.5

func _process(_delta: float) -> void:
	if p1_ready and p2_ready and timer.is_stopped():
		timer.start()

func end_game():
	# Transition to next scene or handle game end
	pass

func _on_manger_gameplay_p_1_ready() -> void:
	p1_ready = true
	p1_readiness.animation = "ready"
func _on_manger_gameplay_p_2_ready() -> void:
	p2_ready = true
	p2_readiness.animation = "ready"

func _on_tutocd_timeout() -> void:
	tuto.visible = false
	if not has_started :
		game_timer.start()
		print("Game timer start")
		has_started = true

func open_json(json_path):
	if FileAccess.file_exists(json_path):
		var file = FileAccess.open(json_path, FileAccess.READ)
		var json = file.get_as_text()
		var json_object = JSON.new()
		json_object.parse(json)
		gamestate = json_object.data
		file.close()
		print(gamestate)
	else:
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

func _on_end_timer_timeout() -> void:
	get_tree().change_scene_to_file("res://scenes/organ_stealing.tscn")

func _on_timer_timeout() -> void:
	var winner = ""
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var money_won = rng.randi_range(300, 500)
	
	if mouth_p1.points > mouth_p2.points:
		winner = "0"
		gamestate["players"]["p1"]["score"]+=1
		gamestate["players"]["p1"]["money"]+=money_won
		gamestate["last_winner"]=winner
		write_json(gamestate)
		print("P1 won")
	elif mouth_p1.points > mouth_p2.points:
		winner = "1"
		gamestate["players"]["p2"]["score"]+=1
		gamestate["players"]["p2"]["money"]+=money_won
		gamestate["last_winner"]=winner
		write_json(gamestate)
		print("P2 won")
	else :
		game_timer.start()
		print("No one won !!! Looping back")
	
	
