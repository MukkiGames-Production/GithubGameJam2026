extends Node2D

@export var walls_layer: TileMapLayer
@export var goals_layer: TileMapLayer   # optional

var boxes: Dictionary = {}   # Vector2i → Box

var _signal_update_pending := false
var signal_errors: Array[String] = []

func _ready() -> void:
	# Register every box that is already in the scene
	for box in get_tree().get_nodes_in_group("boxes"):
		if is_ancestor_of(box):
			register_box(box)
	request_signal_update()

func register_box(box: MovingEntity) -> void:
	boxes[box.grid_pos] = box
	request_signal_update()

func unregister_box(box: MovingEntity) -> void:
	if boxes.get(box.grid_pos) == box:
		boxes.erase(box.grid_pos)
	request_signal_update()


## Deferred so a whole chain of pushed boxes updates as one board change.
func request_signal_update() -> void:
	if not is_inside_tree() or _signal_update_pending:
		return
	_signal_update_pending = true
	recalculate_signals.call_deferred()


func recalculate_signals() -> void:
	_signal_update_pending = false
	signal_errors.clear()
	var tiles: Array[SignalTile] = []
	var sources: Dictionary = {}
	var remaining: Dictionary = {}
	var results: Dictionary = {}
	for node in get_tree().get_nodes_in_group("signal_tiles"):
		if node.level == self:
			tiles.append(node)
			sources[node] = []
			remaining[node] = 0
			node.grid_pos = walls_layer.local_to_map(walls_layer.to_local(node.global_position))
			node.incoming_values.clear()
			node.error = ""
	# Tree order gives a stable operand order, independent of signal arrival timing.
	for tile in tiles:
		for destination in tile.destinations:
			if sources.has(destination) and not sources[destination].has(tile):
				sources[destination].append(tile)
				remaining[destination] += 1
			elif not sources.has(destination):
				tile.error = "Destination is missing or belongs to another level."
	var ready: Array[SignalTile] = []
	for tile in tiles:
		if remaining[tile] == 0:
			ready.append(tile)
	while not ready.is_empty():
		var tile: SignalTile = ready.pop_front()
		var inputs: Array[String] = []
		var complete := true
		for source in sources[tile]:
			inputs.append_array(results[source])
			complete = complete and not results[source].is_empty()
		tile.incoming_values = inputs
		var output: Array[String] = []
		var box := get_box_at(tile.grid_pos) as Box
		if box != null and box.val != "-1":
			output = box.evaluate(inputs)
		elif complete:
			output = box.evaluate(inputs) if box != null else inputs.duplicate()
		if box != null and output.is_empty() and complete:
			tile.error = "Invalid value, operator, or number of inputs."
		results[tile] = output
		var sent: Array[SignalTile] = []
		for destination in tile.destinations:
			if remaining.has(destination) and sources[destination].has(tile):
				# Duplicate links represent one connection.
				if sent.has(destination):
					continue
				sent.append(destination)
				remaining[destination] -= 1
				if remaining[destination] == 0:
					ready.append(destination)
	# Publish only after evaluation; cycles and their dependents lose old outputs.
	for tile in tiles:
		if not results.has(tile):
			tile.error = "Signal cycle or dependency on a cycle."
		if not tile.error.is_empty():
			signal_errors.append("%s: %s" % [tile.name, tile.error])
		var values: Array[String] = []
		if results.has(tile):
			values = results[tile]
		tile.publish(values)

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
