extends Node

@onready var p1 = $P1
@onready var p2 = $P2

var challenge_manager: Node

# Animation helper
var _animations: Node = null

# MinigameConnection reference for stake handling
var minigame_connection: Node = null

# Challenge stake information
var current_stake: Dictionary = {
	"organ_wagered": "",
	"stake_multiplier": 1.0,
	"player_index": -1
}

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
# Signal for reporting result to MinigameConnection
signal minigame_result(player_index: int, success: bool, winner: String)

func _ready() -> void:
	# Get animations helper
	_animations = get_node_or_null("/root/Animations")
	
	challenge_manager = Node.new()
	challenge_manager.set_script(preload("res://scripts/core/challenge_manager.gd"))
	challenge_manager.name = "ChallengeManager"
	add_child(challenge_manager)
	setup_challenges()
	challenge_manager.connect("challenge_warning", _on_challenge_warning)

func setup_challenges() -> void:
	# PlayerData is autoloaded - access it via get_node
	var p1_data = _get_player_data("p1")
	var p2_data = _get_player_data("p2")

	challenge_manager.setup_player("p1", p1_data, NAGE_CHALLENGES)
	challenge_manager.setup_player("p2", p2_data, NAGE_CHALLENGES)

func _get_player_data(player_id: String) -> Dictionary:
	# Access autoload via get_node since LSP doesn't recognize autoloads
	var pd = get_node("/root/PlayerData")
	var organs = {}
	for organ_name in ["heart", "lungs", "arms", "legs", "eyes", "pancreas", "brain", "liver", "kidneys"]:
		organs[organ_name] = pd.get_organ_count(organ_name) > 0
	return {
		"id": player_id,
		"score": 0,
		"money": pd.gold,
		"organs": organs
	}

func _process(delta: float) -> void:
	if game_active:
		game_timer += delta
		if game_timer >= game_duration:
			end_game("tie")

func start_game() -> void:
	game_active = true
	game_timer = 0.0
	if _animations:
		_animations.challenge_start_effect()

## Start game with stake information
func start_game_with_stake(player_index: int, organ_wagered: String, multiplier: float = 1.0) -> void:
	set_stake(player_index, organ_wagered, multiplier)
	start_game()

func end_game(winner: String) -> void:
	game_active = false
	game_ended.emit(winner)
	# Report result to MinigameConnection
	emit_signal("minigame_result", current_stake.get("player_index", -1), winner != "tie", winner)
	
	# Apply result animation
	if _animations:
		if winner != "tie":
			_animations.win_text(null, 1.5)
		else:
			_animations.lose_text(null, 1.5)

## Set stake information for this minigame session
func set_stake(player_index: int, organ_wagered: String, multiplier: float = 1.0) -> void:
	current_stake = {
		"player_index": player_index,
		"organ_wagered": organ_wagered,
		"stake_multiplier": multiplier
	}

## Get current stake info
func get_stake() -> Dictionary:
	return current_stake.duplicate(true)

func _on_challenge_warning(player_id: String, organ: String, intensity: float) -> void:
	challenge_warning.emit(player_id, organ, intensity)

func toggle_organ(player_id: String, organ: String) -> void:
	var pd = get_node("/root/PlayerData")
	if pd.get_organ_count(organ) > 0:
		pd.remove_organ(organ, 1)
	else:
		pd.add_organ(organ, 1)
	setup_challenges()
