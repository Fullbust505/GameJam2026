extends Node2D

const TILE_SCENE = preload("res://scenes/tile.tscn")
const TILE_WIDTH = 100
const STARTING_TURNS = 30
const STARTING_MONEY = 500

const MINIGAME_SCENES = [
	"res://scenes/apnee_level.tscn",
	"res://scenes/cam_template.tscn",
	"res://manger/scene/manger_minigame.tscn"
	

]

@onready var turn_label: Label = $UI/TurnLabel
@onready var p1_money_label: Label = $UI/P1Money
@onready var p2_money_label: Label = $UI/P2Money
@onready var roll_prompt: Label = $UI/RollPrompt
@onready var tile_container: Node2D = $Tiles
@onready var camera: Camera2D = $Camera2D

var tiles: Array = []
var players: Array = []
var game_state: Dictionary = {}
var current_roller: int = 0
var turns_remaining: int = STARTING_TURNS
var rng: RandomNumberGenerator
var state: String = "WAITING_ROLL"

func _ready():
	rng = RandomNumberGenerator.new()
	rng.randomize()
	initialize_game()
	generate_initial_tiles()
	setup_players()
	update_ui()

func initialize_game():
	turns_remaining = STARTING_TURNS
	current_roller = 0
	game_state = {
		"turns_remaining": STARTING_TURNS,
		"players": {
			"p1": {"money": STARTING_MONEY, "position": 0, "bag": [], "organs": []},
			"p2": {"money": STARTING_MONEY, "position": 0, "bag": [], "organs": []}
		}
	}

func generate_initial_tiles():
	for i in range(20):
		spawn_tile(i)

func spawn_tile(index: int):
	var tile = TILE_SCENE.instantiate()
	var x_pos = index * TILE_WIDTH + TILE_WIDTH / 2
	tile.position = Vector2(x_pos, get_viewport_rect().size.y / 2)

	# Random tile type: 0=Challenge(red), 1=Shop(green), 2=Event(blue)
	var tile_type = randi() % 3
	var color = Color(1, 0.3, 0.3, 1)
	var text = "C"
	if tile_type == 1:
		color = Color(0.3, 1.0, 0.3, 1)
		text = "S"
	elif tile_type == 2:
		color = Color(0.3, 0.3, 1.0, 1)
		text = "E"

	var color_rect = tile.get_node_or_null("ColorRect")
	if color_rect:
		color_rect.color = color

	var label = tile.get_node_or_null("Label")
	if label:
		label.text = text

	tile_container.add_child(tile)
	tiles.append(tile)

func setup_players():
	var center_y = get_viewport_rect().size.y / 2
	var p1 = $Players/P1Piece
	var p2 = $Players/P2Piece
	p1.position = Vector2(50, center_y - 20)
	p2.position = Vector2(50, center_y + 20)
	players = [p1, p2]
	if camera:
		camera.position = p1.position

func _physics_process(delta: float):
	if state == "WAITING_ROLL":
		if current_roller == 0 and Input.is_action_just_pressed("p1_main_button"):
			roll_dice()
		elif current_roller == 1 and Input.is_action_just_pressed("p2_main_button"):
			roll_dice()

	# Smooth camera follow current player
	if players.size() > current_roller and players[current_roller]:
		var target = players[current_roller].global_position
		camera.position.x = lerp(camera.position.x, target.x, 5.0 * delta)
		camera.position.y = lerp(camera.position.y, target.y, 5.0 * delta)

func roll_dice():
	var roll = rng.randi_range(1, 6)
	state = "MOVING"
	print("P%d rolled %d" % [current_roller + 1, roll])

	# Move both players based on current roller's roll
	for i in range(2):
		var player_key = "p%d" % (i + 1)
		var pos = game_state["players"][player_key]["position"]
		pos += roll
		game_state["players"][player_key]["position"] = pos
		players[i].move_to(tiles[pos % tiles.size()].position)

	# Ensure more tiles exist ahead
	while tiles.size() < (game_state["players"]["p1"]["position"] / TILE_WIDTH) + 30:
		spawn_tile(tiles.size())

	# Wait 5 seconds before triggering tile effect
	state = "MOVING"
	await get_tree().create_timer(5.0).timeout

	# Trigger tile effect for the roller
	var roller_pos = game_state["players"]["p%d" % (current_roller + 1)]["position"]
	var tile_idx = roller_pos % tiles.size()
	trigger_tile_effect(current_roller, tile_idx)

func trigger_tile_effect(player_idx: int, tile_idx: int):
	var tile_type = get_tile_type(tile_idx)

	match tile_type:
		0:  # Challenge - launch random minigame
			var minigame = MINIGAME_SCENES[randi() % MINIGAME_SCENES.size()]
			print("Challenge! Launching: ", minigame)
			get_tree().change_scene_to_file(minigame)
		1:  # Shop
			print("Shop! Opening shop...")
			get_tree().change_scene_to_file("res://scenes/shop.tscn")
		2:  # Event
			trigger_random_event(player_idx)
			state = "TRANSITIONING"
			await get_tree().create_timer(1.5).timeout
			end_turn()

func get_tile_type(tile_idx: int) -> int:
	var tile = tiles[tile_idx % tiles.size()]
	var color_rect = tile.get_node_or_null("ColorRect")
	if color_rect:
		var c = color_rect.color
		if c.r > 0.9: return 0      # Red = Challenge
		elif c.g > 0.9: return 1   # Green = Shop
		else: return 2              # Blue = Event
	return 0

func trigger_random_event(player_idx: int):
	var player_key = "p%d" % (player_idx + 1)
	var events = [
		{"text": "Found 50 coins!", "type": "gain", "amount": 50},
		{"text": "Jackpot! Found 100 coins!", "type": "gain", "amount": 100},
		{"text": "Pickpocket! Lost 30 coins.", "type": "lose", "amount": 30},
		{"text": "Bad luck! Lost 50 coins.", "type": "lose", "amount": 50},
		{"text": "Lucky! Found an eye!", "type": "organ", "name": "eye"},
		{"text": "Ouch! Lost a tooth!", "type": "organ_lose", "name": "tooth"}
	]
	var event = events[randi() % events.size()]
	match event["type"]:
		"gain":
			game_state["players"][player_key]["money"] += event["amount"]
		"lose":
			game_state["players"][player_key]["money"] = max(0, game_state["players"][player_key]["money"] - event["amount"])
		"organ":
			game_state["players"][player_key]["organs"].append(event["name"])
		"organ_lose":
			var organs = game_state["players"][player_key]["organs"]
			var idx = organs.find(event["name"])
			if idx >= 0:
				organs.remove_at(idx)

	print("Event: ", event["text"])
	show_event_popup(event["text"])

func show_event_popup(text: String):
	var popup = AcceptDialog.new()
	popup.dialog_text = text
	get_tree().current_scene.add_child(popup)
	popup.popup_centered()
	await popup.confirmed
	popup.queue_free()

func end_turn():
	current_roller = 1 - current_roller
	if current_roller == 0:
		turns_remaining -= 1

	if turns_remaining <= 0:
		declare_winner()
		return

	state = "WAITING_ROLL"
	update_ui()

func declare_winner():
	var p1 = game_state["players"]["p1"]["money"]
	var p2 = game_state["players"]["p2"]["money"]
	var winner = 0 if p1 > p2 else 1 if p2 > p1 else -1
	print("Player %d wins with $%d vs $%d!" % [winner + 1, p1, p2])

func update_ui():
	if turn_label:
		turn_label.text = "Turns: %d" % turns_remaining
	if p1_money_label:
		p1_money_label.text = "P1: $%d" % game_state["players"]["p1"]["money"]
	if p2_money_label:
		p2_money_label.text = "P2: $%d" % game_state["players"]["p2"]["money"]
	if roll_prompt:
		roll_prompt.text = "P%d: Press A to Roll" % (current_roller + 1)
