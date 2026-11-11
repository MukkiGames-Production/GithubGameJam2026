extends Node2D

@onready var gate_physical: Node2D = $gate_physical

var is_open : bool = false # false = closed

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func incoming_signal(truth: bool):
	# eval the block(s) on the activator tile
	#var block = gate_activator_tiles.get_tile.get_current_block()
	#var val = block.get_value()
	#if val != null:
	
	# Any nonzero binary value is considered true
	#var truth : bool = val.bin_to_int() != 0
	change_gate_state(truth)

func change_gate_state(truth: bool):
	if truth:
		if is_open:
			pass
		else:
			open()
	else:
		if is_open:
			close()
		else:
			pass

func open():
	pass

func close():
	pass
