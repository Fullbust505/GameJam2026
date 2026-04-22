class_name EventSystem
extends Node

var rng: RandomNumberGenerator

func _init():
	rng = RandomNumberGenerator.new()
	rng.randomize()

enum EventType { GAIN_MONEY, LOSE_MONEY, STEAL_ITEM, GAIN_ORGAN, LOSE_ORGAN }

static func get_all_events() -> Array:
	return [
		{"type": "gain_money", "amount": 50, "text": "Found 50 coins!"},
		{"type": "gain_money", "amount": 100, "text": "Jackpot! 100 coins!"},
		{"type": "lose_money", "amount": 30, "text": "Pickpocket! Lost 30 coins."},
		{"type": "lose_money", "amount": 50, "text": "Bad luck! Lost 50 coins."},
		{"type": "steal_item", "text": "Stole an item from opponent!"},
		{"type": "gain_organ", "organ": "heart", "text": "Found a heart!"},
		{"type": "gain_organ", "organ": "eye", "text": "Found an eye!"},
		{"type": "lose_organ", "organ": "tooth", "text": "Lost a tooth!"},
	]

func generate_random_event() -> Dictionary:
	var events = get_all_events()
	return events[randi() % events.size()].duplicate(true)

func apply_event(event: Dictionary, game_state: Dictionary, player_key: String):
	match event.get("type"):
		"gain_money":
			game_state["players"][player_key]["money"] += event.get("amount", 0)
		"lose_money":
			game_state["players"][player_key]["money"] = max(0, game_state["players"][player_key]["money"] - event.get("amount", 0))
		"steal_item":
			var opponent_key = "p2" if player_key == "p1" else "p1"
			if game_state["players"][opponent_key]["bag"].size() > 0:
				var item = game_state["players"][opponent_key]["bag"].pop_back()
				game_state["players"][player_key]["bag"].append(item)
		"gain_organ":
			game_state["players"][player_key]["organs"].append(event.get("organ", "unknown"))
		"lose_organ":
			var organ = event.get("organ", "unknown")
			var organs = game_state["players"][player_key]["organs"]
			var idx = organs.find(organ)
			if idx >= 0:
				organs.remove_at(idx)
