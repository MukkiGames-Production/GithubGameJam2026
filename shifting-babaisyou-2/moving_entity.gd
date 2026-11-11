extends Node2D
class_name MovingEntity

@export var tile_size: int = 64
@export var move_speed: float = 8.0

var grid_pos: Vector2i
var moving: bool = false

var level: Node2D   # will be set in _ready

func _ready() -> void:
	# Walk up the tree until we find the Level (the node that has walls_layer)
	level = _find_level()
	if level == null:
		push_error("MovingEntity could not find Level!")
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
	return level.walls_layer.to_global(level.walls_layer.map_to_local(grid)) \
		+ Vector2(tile_size * 0.5, tile_size * 0.5)

func is_wall(cell: Vector2i) -> bool:
	return level.is_wall(cell)

func try_move(dir: Vector2i) -> bool:
	if moving or dir == Vector2i.ZERO:
		return false

	var target := grid_pos + dir

	if is_wall(target):
		return false

	if not can_move_to(target, dir):
		return false

	# Update registry if this is a box
	if is_in_group("boxes"):
		level.unregister_box(self)

	grid_pos = target

	if is_in_group("boxes"):
		level.register_box(self)

	moving = true

	var tween := create_tween()
	tween.tween_property(self, "global_position", grid_to_world(grid_pos), 1.0 / move_speed)\
		.set_trans(Tween.TRANS_SINE)

	await tween.finished
	moving = false

	_on_move_finished()
	return true

func can_move_to(_target: Vector2i, _dir: Vector2i) -> bool:
	return true

func _on_move_finished() -> void:
	pass
