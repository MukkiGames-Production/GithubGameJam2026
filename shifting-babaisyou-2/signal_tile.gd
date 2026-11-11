extends Node2D
class_name SignalTile
## Place over a TileMap cell, or use SignalTile.tscn as a scene-collection tile.
## Source tile scene-tree order defines operands: shift value first, amount second.

@export var destinations: Array[Node2D] = [] # Assign other SignalTile nodes.
@export var receivers: Array[Node] = [] # Nodes exposing incoming_signal(bool), e.g. gates.

var grid_pos: Vector2i
var incoming_values: Array[String] = []
var output_values: Array[String] = []
var error: String = ""
var level: Node2D


func _ready() -> void:
	add_to_group("signal_tiles")
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor.has_method("request_signal_update"):
			level = ancestor
			break
		ancestor = ancestor.get_parent()
	if level != null:
		level.request_signal_update()


func _exit_tree() -> void:
	if is_instance_valid(level):
		level.request_signal_update()


func publish(values: Array[String]) -> void:
	output_values = values.duplicate()
	# Aggregate truth for boolean endpoints, retaining the full bit strings between tiles.
	var truth := false
	for value in output_values:
		truth = truth or value.contains("1")
	for receiver in receivers:
		if is_instance_valid(receiver) and receiver.has_method("incoming_signal"):
			receiver.incoming_signal(truth)
