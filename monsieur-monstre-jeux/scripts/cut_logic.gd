extends Node
@onready var timer = $"mg_duration"
@onready var label = $"../../../../Label"
@onready var tuto = $"../../../../tuto"
@onready var p1_readiness = $"../../../../p1readiness"
@onready var p2_readiness = $"../../../../p2readiness"
@export var number_of_cuts = randi_range(8,12)
@onready var tuto_label = $"../../../../tuto/tuto_desc"
var json_path = "res://game_state.json"
var json_path_backup = "res://game_state_backup.json"
var gamestate : Dictionary = {}

@onready var end_times = $end_timer

@onready var organ_steal = "res://scenes/organ_stealing.tscn"

var timeouts = 0
var p1_ready = false
var p2_ready = false
var finish_p1 = false
var finish_p2 = false

func _ready() -> void:
	open_json(json_path)
	p1_readiness.animation = "waiting"
	p2_readiness.animation = "waiting"
	tuto_label.text = "In this minigame, you will have to cut\n this piece of meat\n in %d pieces of the same size !" % [number_of_cuts]
	timer.wait_time = 4

func _process(_delta: float) -> void:
	if end_times.is_stopped():
		if finish_p1 and finish_p2 and not timer.is_stopped() :
			timer.stop()
			end_game()
		else:
			if p1_ready and p2_ready and timeouts==0 and timer.is_stopped():
				timer.start()
			var s_dur = timer.time_left
			if timeouts==0:
				label.text = '%02d' % [s_dur]
			elif timeouts ==1:
				label.text = '%02d' % [s_dur]
			if s_dur<1:
				label.text = ''

func _on_mg_duration_timeout() -> void:
	timeouts+=1
	if timeouts ==1:
		tuto.visible=false
		p1_readiness.visible = false
		p2_readiness.visible=false
		timer.wait_time = 10
		timer.start()
	if timeouts == 2:
		end_game()

func end_game():
	var winner = ""
	var perfect_length = 330/number_of_cuts-1
	
	var p1_cuts = $P1.cut_positions
	var p1_diff = 0.0
	
	var p2_cuts = $P2.cut_positions
	var p2_diff = 0.0
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var money_won = rng.randi_range(300, 500)
	
	if p1_cuts.size()!=number_of_cuts-1 and p2_cuts.size()==number_of_cuts-1:
		winner = "0"
		gamestate["players"]["p1"]["score"]+=1
		gamestate["players"]["p1"]["money"]+=money_won
	elif p1_cuts.size()==number_of_cuts-1 and p2_cuts.size()!=number_of_cuts-1:
		winner = "1"
		gamestate["players"]["p2"]["score"]+=1
		gamestate["players"]["p2"]["money"]+=money_won
	else:
		p1_cuts.insert(0, 165)
		p1_cuts.insert(-1, -165)
		p1_cuts.sort()

		p2_cuts.insert(0, 165)
		p2_cuts.insert(-1, -165)
		p2_cuts.sort()
		
		for i in range(p1_cuts.size()-1):
			print(p1_diff)
			p1_diff+=abs(p1_cuts[i+1]-p1_cuts[i]-perfect_length)
			
		for j in range(p2_cuts.size()-1):
			print(p2_diff)
			p2_diff+=abs(p2_cuts[j+1]-p2_cuts[j]-perfect_length)
		
		if p2_diff < p1_diff:
			winner = "1"
			gamestate["players"]["p2"]["score"]+=1
			gamestate["players"]["p2"]["money"]+=300
		else :
			winner = "0"
			gamestate["players"]["p1"]["score"]+=1
			gamestate["players"]["p1"]["money"]+=300
	
	gamestate["last_winner"]=winner
	write_json(gamestate)
	
	end_times.start()

func _on_p1_ready() -> void:
	p1_ready = true
	p1_readiness.animation = "ready"
func _on_p2_ready() -> void:
	p2_ready = true
	p2_readiness.animation = "ready"

func _on_finish_p1() -> void:
	finish_p1=true
func _on_finish_p2() -> void:
	finish_p2 = true

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
