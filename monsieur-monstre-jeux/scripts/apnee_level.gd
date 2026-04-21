extends Node

@onready var p1 = $P1
@onready var p2 = $P2

var challenge_manager: Node

const NAGE_CHALLENGES = {
	"heart": {
		"type": "joystick_pump",
		"interval": 10.0,
		"window": 1.0,
		"warning": "once"
	},
	"lungs": {
		"type": "continuous_alternate",
		"required_rate": 4.0,
		"warning": "dynamic"
	},
	"arms": {
		"type": "periodic_tap",
		"interval": 3.0,
		"window": 1.0,
		"button": "game_main_button",
		"warning": "always"
	},
	"legs": {
		"type": "periodic_tap",
		"interval": 4.0,
		"window": 1.0,
		"button": "game_secondary_button",
		"warning": "always"
	},
	"pancreas": {
		"type": "qte_sequence",
		"interval_min": 15.0,
		"interval_max": 30.0,
		"sequence": ["a", "a", "b"],
		"warning": "always"
	},
	"eyes": {
		"type": "blink",
		"interval": 5.0,
		"button": "game_main_button",
		"warning": "always"
	}
}

var game_active: bool = false
var game_duration: float = 60.0
var game_timer: float = 0.0

signal game_ended(winner: String)
signal challenge_warning(player_id: String, organ: String, intensity: float)

func _ready() -> void:
	challenge_manager = Node.new()
	challenge_manager.set_script(preload("res://scripts/core/challenge_manager.gd"))
	challenge_manager.name = "ChallengeManager"
	add_child(challenge_manager)
	setup_challenges()
	challenge_manager.connect("challenge_warning", _on_challenge_warning)

func setup_challenges() -> void:
	var p1_data = PlayerData.get_player("p1")
	var p2_data = PlayerData.get_player("p2")

	challenge_manager.setup_player("p1", p1_data, NAGE_CHALLENGES)
	challenge_manager.setup_player("p2", p2_data, NAGE_CHALLENGES)

func _process(delta: float) -> void:
	if game_active:
		game_timer += delta
		if game_timer >= game_duration:
			end_game("tie")

func start_game() -> void:
	game_active = true
	game_timer = 0.0

func end_game(winner: String) -> void:
	game_active = false
	emit_signal("game_ended", winner)

func _on_challenge_warning(player_id: String, organ: String, intensity: float) -> void:
	emit_signal("challenge_warning", player_id, organ, intensity)

func toggle_organ(player_id: String, organ: String) -> void:
	if PlayerData.has_organ(player_id, organ):
		PlayerData.remove_organ(player_id, organ)
	else:
		PlayerData.add_organ(player_id, organ)
	setup_challenges()