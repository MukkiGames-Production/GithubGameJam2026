extends Node2D

@export var walls_layer: TileMapLayer
@export var goals_layer: TileMapLayer   # optional

var boxes: Dictionary = {}   # Vector2i → Box

func _ready() -> void:
	# Register every box that is already in the scene
	for box in get_tree().get_nodes_in_group("boxes"):
		register_box(box)

func register_box(box: MovingEntity) -> void:
	boxes[box.grid_pos] = box

func unregister_box(box: MovingEntity) -> void:
	if boxes.get(box.grid_pos) == box:
		boxes.erase(box.grid_pos)

func get_box_at(cell: Vector2i) -> MovingEntity:
	return boxes.get(cell)

func is_wall(cell: Vector2i) -> bool:
	return walls_layer.get_cell_source_id(cell) != -1

func check_win() -> bool:
	if goals_layer == null:
		return false
	
	var goals := goals_layer.get_used_cells()
	if goals.is_empty():
		return false
	
	for goal in goals:
		if get_box_at(goal) == null:
			return false
	
	print("Level Complete!")
	return true
