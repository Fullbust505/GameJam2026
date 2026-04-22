extends Control
@onready var timer = Timer.new()
@onready var p1_readiness = $"p1readiness"
@onready var p2_readiness = $"p2readiness"

var p1_ready = false
var p2_ready = false
var timeouts = 0

# Frame indices for sprite grid
const FRAME_WAITING = 0
const FRAME_READY = 1
const FRAME_ACTIVE = 2

func _ready() -> void:
	add_child(timer)
	timer.timeout.connect(_on_timer_timeout)
	p1_readiness.frame = FRAME_WAITING
	p2_readiness.frame = FRAME_WAITING
	timer.wait_time = 4

func _process(_delta: float) -> void:
	if p1_ready and p2_ready and timeouts == 0 and timer.is_stopped():
		timer.start()
	
	var s_dur = timer.time_left
	if timeouts == 0:
		# Timer is running, show countdown
		pass
	elif timeouts == 1:
		# Game is running
		pass

func _on_timer_timeout() -> void:
	timeouts += 1
	if timeouts == 1:
		p1_readiness.frame = FRAME_ACTIVE
		p2_readiness.frame = FRAME_ACTIVE
		timer.wait_time = 10
		timer.start()
	if timeouts == 2:
		end_game()

func _on_p1_ready() -> void:
	p1_ready = true
	p1_readiness.frame = FRAME_READY

func _on_p2_ready() -> void:
	p2_ready = true
	p2_readiness.frame = FRAME_READY

func end_game():
	# Transition to next scene or handle game end
	pass
