extends MovingEntity
class_name Box

@export var val: String = "-1":
	set(value):
		val = value
		_refresh_signals()
@export var op: String = "NONE":
	set(value):
		op = value.to_upper()
		_refresh_signals()

func _ready() -> void:
	super._ready()
	add_to_group("boxes")
	if level != null:
		level.register_box(self)

func _exit_tree() -> void:
	if is_instance_valid(level):
		level.unregister_box(self)

func _refresh_signals() -> void:
	if is_instance_valid(level) and level.has_method("request_signal_update"):
		level.request_signal_update()

func get_truth() -> bool:
	return Operators.is_binary(val) and val.contains("1")

func get_value() -> String:
	return val

func get_operator() -> String:
	return op

func get_val_or_op() -> String:
	if val != "-1":
		return val
	elif op != "NONE":
		return op
	else:
		return ""

## Value boxes are sources; operator boxes transform all incoming values.
func evaluate(inputs: Array[String]) -> Array[String]:
	var output: Array[String] = []
	if val != "-1":
		if Operators.is_binary(val):
			output.append(val)
		return output
	if op != "NONE":
		var result := Operators.evaluate(op, inputs)
		if not result.is_empty():
			output.append(result)
		return output
	return inputs.duplicate()
