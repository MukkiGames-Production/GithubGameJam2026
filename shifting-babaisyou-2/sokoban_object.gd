extends Node2D
class_name SokobanObject

var level: Node2D
var grid_pos: Vector2i

func _ready() -> void:
	# Walk up the tree until we find the Level (the node that has walls_layer)
	level = _find_level()
	if level == null:
		push_error("Some Entity could not find Level!")
		return

	# Snap to grid
	grid_pos = world_to_grid(global_position)
	global_position = grid_to_world(grid_pos)
	
func _find_level() -> Node2D:
	var node = self
	while node:
		if node.get("walls_layer") != null:   # duck typing – looks for the export
			return node
		node = node.get_parent()
	return null

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return level.walls_layer.local_to_map(level.walls_layer.to_local(world_pos))

func grid_to_world(grid: Vector2i) -> Vector2:
	return level.walls_layer.to_global(level.walls_layer.map_to_local(grid))
