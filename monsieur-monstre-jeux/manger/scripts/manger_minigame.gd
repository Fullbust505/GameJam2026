extends Control
@onready var p1_readiness = $manger_tuto/p1readiness
@onready var p2_readiness = $manger_tuto/p2readiness
@onready var timer = $tutocd
@onready var tuto = $manger_tuto

var p1_ready = false
var p2_ready = false


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
