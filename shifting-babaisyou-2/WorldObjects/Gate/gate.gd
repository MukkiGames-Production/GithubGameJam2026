extends Node2D

var is_open : bool = false # false = closed
var _state_reported := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	change_gate_state(is_open)


func incoming_signal(truth: bool):
	change_gate_state(truth)



func change_gate_state(truth: bool):
	if _state_reported and is_open == truth:
		return
	is_open = truth
	_state_reported = true
	print("Gate open: ", is_open)

func open():
	change_gate_state(true)

func close():
	change_gate_state(false)
