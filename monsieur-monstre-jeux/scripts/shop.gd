extends Node2D
var articles = []
var json_path = "res://game_state.json"
var gamestate : Dictionary = {}
var atlas : int = 0
var beatles: int = 0
@onready var bag = $Articles
@onready var p1_hand = $p1_hand
@onready var p2_hand = $p2_hand
@onready var p1_x_timer = $p1_x_timer
@onready var p1_y_timer = $p1_y_timer
@onready var p2_x_timer = $p2_x_timer
@onready var p2_y_timer = $p2_y_timer
@onready var p1_readiness = $"p1readiness"
@onready var p2_readiness = $"p2readiness"
@onready var tuto_label = $tuto_shop/tuto_desc
@onready var timer = $mg_duration

@onready var p1_label = $p1_money
@onready var p2_label = $p2_money

var p1_hand_index : int = 0
var p2_hand_index : int = 0

var timeouts = 0
var p1_ready = false
var p2_ready = false
var allready = false
var p1_done = false
var p2_done = false

var rand_game =0

@onready var end_times = $end_timer

@onready var blackscreen = $bkc_screen_on_win
@onready var winner_lab = $winner

func _ready() -> void:
	open_json(json_path)
	p1_readiness.animation = "waiting"
	p2_readiness.animation = "waiting"
	tuto_label.text = "Welcome to the shop!\nHere, buy body parts with A\nand quit with B."
	timer.wait_time = 1.5
	choose_random_articles()
	p1_label.text = "Player 1 Money : %.00d B" % [gamestate["players"]["p1"]["money"]]
	p2_label.text = "Player 2 Money : %.00d B" %  [gamestate["players"]["p2"]["money"]]
	blackscreen.visible = false
	winner_lab.visible = false
	

func _physics_process(delta: float) -> void:
	if allready :
		if not p1_done:
			p1_hand_index = p1_movement(p1_hand_index)
			if Input.is_joy_button_pressed(0, JOY_BUTTON_A) and Input.is_action_just_pressed("game_main_button"):
				buy_item(0, p1_hand_index)
		
		if not p2_done:
			p2_hand_index = p2_movement(p2_hand_index)
			if Input.is_joy_button_pressed(1, JOY_BUTTON_A) and Input.is_action_just_pressed("game_main_button"):
				buy_item(1, p2_hand_index)

		if Input.is_joy_button_pressed(0, JOY_BUTTON_B) and Input.is_action_just_pressed("game_sub_button"):
			p1_done = true
			p1_hand.modulate = Color(0.2,0,0)
		
		if Input.is_joy_button_pressed(1, JOY_BUTTON_B) and Input.is_action_just_pressed("game_sub_button"):
			p2_done = true
			p2_hand.modulate = Color(0,0,0.2)
		
		if p1_done and p2_done and end_times.is_stopped():
			end_shop()
	elif p1_ready and p2_ready and timer.is_stopped() :
		timer.start()
		print("OK")
	
	if gamestate["players"]["p1"]["bag"].size()>=5:
		win_game("p1")
	elif gamestate["players"]["p1"]["bag"].size()>=5:
		win_game("p2")
	
func buy_item(player_index, hand_index):
	for i in range(articles.size()):
		if articles[i][1]==hand_index and gamestate["players"]["p"+str(player_index+1)]["money"]>=articles[i][3]:
			articles[i][2].visible=false
			gamestate["players"]["p"+str(player_index+1)]["money"]-=articles[i][3]
			gamestate["players"]["p"+str(player_index+1)]["bag"].append([bag.get_child(articles[i][0]).name,articles[i][3]])
			articles.pop_at(i)
			p1_label.text = "Player 1 Money : %.00d B" % [gamestate["players"]["p1"]["money"]]
			p2_label.text = "Player 2 Money : %.00d B" % [gamestate["players"]["p2"]["money"]]
			$CaChingSound.play()
			break

func open_json(json_path):
	var file = FileAccess.open(json_path, FileAccess.READ)
	
	var json = file.get_as_text()
	var json_object = JSON.new()
	
	json_object.parse(json)
	gamestate = json_object.data
	file.close()
	
func write_json(gamestate):
	var file = FileAccess.open("res://game_state.json", FileAccess.WRITE)
	var json_text = JSON.stringify(gamestate, '\t')
	
	file.store_string(json_text)
	file.close()

func p1_movement(index):
	var p1_x = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var p1_y = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	
	if abs(p1_x)>0.5 and p1_x_timer.is_stopped():
		if (int(index)%3)==0 and p1_x > 0 :
			index+=1
			p1_x_timer.start()
		elif ((int(index)-1)%3)==0 :
			index += sign(p1_x)
			p1_x_timer.start()
		elif ((int(index)-2)%3)==0 and p1_x < 0 :
			index-=1
			p1_x_timer.start()

	if abs(p1_y)>0.5 and p1_y_timer.is_stopped():
		p1_y_timer.start()
		if index < 3 and p1_y > 0:
			index+=3
			p1_y_timer.start()
		if index > 2 and p1_y < 0:
			index-=3
			p1_y_timer.start()
			
	p1_hand.position.x=56 + (int(index)%3) * 194
	if (index>2):
		p1_hand.position.y=250
	else:
		p1_hand.position.y=123
	
	return index

func p2_movement(index):
	var p2_x = Input.get_joy_axis(1, JOY_AXIS_LEFT_X)
	var p2_y = Input.get_joy_axis(1, JOY_AXIS_LEFT_Y)
	
	if abs(p2_x)>0.5 and p2_x_timer.is_stopped():
		if (int(index)%3)==0 and p2_x > 0 :
			index+=1
			p2_x_timer.start()
		elif ((int(index)-1)%3)==0 :
			index += sign(p2_x)
			p2_x_timer.start()
		elif ((int(index)-2)%3)==0 and p2_x < 0 :
			index-=1
			p2_x_timer.start()
	
	if abs(p2_y)>0.5 and p2_y_timer.is_stopped():
		p2_y_timer.start()
		if index < 3 and p2_y > 0:
			index+=3
			p2_y_timer.start()
		if index > 2 and p2_y < 0:
			index-=3
			p2_y_timer.start()
			
	p2_hand.position.x=206 + (int(index)%3) * 194
	if (index>2):
		p2_hand.position.y=250
	else:
		p2_hand.position.y=123
	
	return index

func choose_random_articles():
	for article in bag.get_children():
		article.visible=false
	
	var article1 = randi_range(0,6)
	var article2 = randi_range(0,6)
	while article2 == article1:
		article2 = randi_range(0,6)
	var article3 = randi_range(0,6)
	while article3 == article2 or article3 == article1:
		article3 = randi_range(0,6)
	articles.append([article1])
	articles.append([article2])
	articles.append([article3])
	
	articles.sort()
	
	var article_place1 = randi_range(0,5)
	var article_place2 = randi_range(0,5)
	while article_place2 == article_place1:
		article_place2 = randi_range(0,5)
	var article_place3 = randi_range(0,5)
	while article_place3 == article_place2 or article_place3 == article_place1:
		article_place3 = randi_range(0,5)
	articles[0].append(article_place1)
	articles[1].append(article_place2)
	articles[2].append(article_place3)
	
	for article in bag.get_children():
		for article_index in articles:
			if atlas == article_index[0]:
				article.visible=true
				articles[beatles].append(article)
				beatles+=1
		atlas+=1
	
	for article in articles:
		article[2].position.x = 132 + article[1]%3 * 194
		if (article[1])>2:
			article[2].position.y = 68 + 127
		else:
			article[2].position.y = 68
	
	var article_price_1 = int(100 * randf_range(1,3))
	var article_price_2 = int(100 * randf_range(2,4))
	var article_price_3 = int(100 * randf_range(3,5))
	var prices : Array = [article_price_1,article_price_2,article_price_3]
	var indexalacon : int = 0
	
	for article in articles:
		article.append(prices[indexalacon])
		indexalacon+=1
		article[2].get_child(-1).text = str(prices[indexalacon-1]) + " B"
	print(articles)

func end_shop():
	print(gamestate)
	write_json(gamestate)
	end_times.start()

func _on_end_timer_timeout() -> void:
	rand_game = randi_range(0,10)
	if rand_game > -1:
		get_tree().change_scene_to_file("res://scenes/cam_template.tscn")
	else:
		get_tree().change_scene_to_file("res://manger/scene/manger_minigame.tscn")

func _on_mg_duration_timeout() -> void:
	$tuto_shop.visible=false
	p1_readiness.visible = false
	p2_readiness.visible = false
	allready = true


func _on_p_2_hand_ready_p_2() -> void:
	p2_ready = true
	p2_readiness.animation = "ready"

func _on_p_1_hand_ready_p_1() -> void:
	p1_ready = true
	p1_readiness.animation = "ready"

func win_game(p_index):
	blackscreen.visible = true
	winner_lab.visible = true
	winner_lab.text = str(p_index)+"won!"
	
