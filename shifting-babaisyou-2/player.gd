extends Node2D

@export var tile_size: int = 64
@export var move_speed: float = 8.0

# References to all your specific TileMapLayers from the Inspector
@export var walls_layer: TileMapLayer
@export var boxes_layer: TileMapLayer
@export var modifiers_layer: TileMapLayer  # Added to track your goal markings!

var inputs := {
	&"ui_right": Vector2.RIGHT,
	&"ui_left": Vector2.LEFT,
	&"ui_up": Vector2.UP,
	&"ui_down": Vector2.DOWN
}

var moving := false
var desired_dir: Vector2 = Vector2.ZERO   

func _ready() -> void:
	position = position.snapped(Vector2.ONE * tile_size) + Vector2.ONE * (tile_size / 2.0)

func _unhandled_input(event: InputEvent) -> void:
	for action in inputs:
		if event.is_action_pressed(action):
			desired_dir = inputs[action]
			if not moving:
				try_move()
			return   

	for action in inputs:
		if event.is_action_released(action) and inputs[action] == desired_dir:
			desired_dir = Vector2.ZERO
			return

func try_move() -> void:
	if desired_dir == Vector2.ZERO or moving:
		return

	var current_tile := walls_layer.local_to_map(position)
	var next_tile := current_tile + Vector2i(desired_dir)
	var next_next_tile := next_tile + Vector2i(desired_dir)

	if is_wall(next_tile):
		return

	if is_box(next_tile):
		if is_wall(next_next_tile) or is_box(next_next_tile):
			return
		else:
			move_box_tile(next_tile, next_next_tile)
			# Check if the player won after moving a box
			check_win_condition()

	moving = true
	var target := position + desired_dir * tile_size

	var tween := create_tween()
	tween.tween_property(self, "position", target, 1.0 / move_speed).set_trans(Tween.TRANS_SINE)
	await tween.finished
	moving = false

	try_move()

func is_wall(cell_coord: Vector2i) -> bool:
	return walls_layer.get_cell_source_id(cell_coord) != -1

func is_box(cell_coord: Vector2i) -> bool:
	return boxes_layer.get_cell_source_id(cell_coord) != -1

func move_box_tile(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var source_id := boxes_layer.get_cell_source_id(from_cell)
	var atlas_coords := boxes_layer.get_cell_atlas_coords(from_cell)
	var alternative_tile := boxes_layer.get_cell_alternative_tile(from_cell)
	
	boxes_layer.set_cell(to_cell, source_id, atlas_coords, alternative_tile)
	boxes_layer.set_cell(from_cell, -1)

# New Helper: Scans the level to see if every goal cell is covered by a box cell
func check_win_condition() -> void:
	var all_goals := modifiers_layer.get_used_cells()
	
	# If there are no goals placed in the level, don't trigger a win
	if all_goals.is_empty():
		return
		
	for goal_cell in all_goals:
		# If any goal cell does NOT have a box on it, the puzzle is not solved yet
		if not is_box(goal_cell):
			return
			
	print("Level Complete! All boxes are on goals.")
	# Add your scene transition or victory screen logic here
