extends Node
var json_path = "res://game_state.json"
var gamestate : Dictionary = {}
var available_organs: Array = []
var player_index = 3
var bp_id = 0
var select = 0.0
var indexalacon = 0
@onready var vis_timer = $"Visibility Timer"
@onready var sel_timer = $"Select Timer"
@onready var end_timer = $"Ending Timer"
var victim = ""

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	open_json(json_path)
	player_index = int(gamestate["last_winner"])
	if player_index==0:
		victim = "p2"
	else:
		victim = "p1"
	for organ in gamestate["players"][victim]["organs"].keys():
		available_organs.append([gamestate["players"][victim]["organs"][organ]])
	for i in range(available_organs.size()):
		available_organs[i].append($Body.get_child(i))
		if not available_organs[i][0]:
			available_organs[i][1].modulate = Color(0,0,0)
	for child in $Body.get_children():
		child.visible = true
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if end_timer.is_stopped():
		if Input.is_joy_button_pressed(player_index, JOY_BUTTON_A) and Input.is_action_just_pressed("game_main_button") and available_organs[bp_id][0]:
			for organ in gamestate["players"][victim]["organs"].keys():
				if indexalacon == bp_id:
					print(gamestate)
					print("you stole " + organ)
					gamestate["players"][victim]["organs"][organ]=false
					end_steal(gamestate)
				indexalacon+=1
				

		select = Input.get_joy_axis(player_index, JOY_AXIS_LEFT_X)
		if abs(select) > 0.5 and sel_timer.is_stopped():
			sel_timer.start()
			bp_id+=1*sign(select)
			if bp_id==-1:
				bp_id=available_organs.size()-1
				selection(bp_id,0)
			elif bp_id==available_organs.size():
				bp_id=0
				selection(bp_id,6)
			else:
				selection(bp_id,sign(select))

func selection(bp_id, dir):
	var bp_previous :int = 0
	if abs(dir)==1:
		bp_previous = bp_id-dir
	else:
		bp_previous = dir
	var previous_sprite = available_organs[bp_previous][1]
	previous_sprite.visible=true

	var sprite = available_organs[bp_id][1]
	available_organs[bp_id][1].visible=false
	vis_timer.stop()
	vis_timer.start()
	if not available_organs[bp_id][0]:
		sprite.modulate = Color(0,0,0)

func open_json(json_path):
	var file = FileAccess.open(json_path, FileAccess.READ)
	
	var json = file.get_as_text()
	var json_object = JSON.new()
	
	json_object.parse(json)
	gamestate = json_object.data
	file.close()
	
func write_json(gamestate):
	var file = FileAccess.open("res://game_state_new.json", FileAccess.WRITE)
	var json_text = JSON.stringify(gamestate, '\t')
	
	file.store_string(json_text)
	file.close()

func _on_visibility_timer_timeout() -> void:
	available_organs[bp_id][1].visible = not available_organs[bp_id][1].visible 
	vis_timer.start()

func end_steal(gamestate):
	write_json(gamestate)
	end_timer.start()
	print(gamestate)

func _on_ending_timer_timeout() -> void:
	print("change the game scene fils de pute")
