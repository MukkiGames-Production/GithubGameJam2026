extends MovingEntity
class_name Box

## All segments that belong to this box (filled automatically in _ready)
const SEGMENT_SCENE = preload("res://MovingEntities/Box/BoxSegment.tscn")
var segments: Array[BoxSegment] = []

func _ready() -> void:
	super._ready()
	add_to_group("boxes")

	# Collect child segments
	for child in get_children():
		if child is BoxSegment:
			segments.append(child)

	if level:
		level.register_box(self)

func _exit_tree() -> void:
	if is_instance_valid(level):
		level.unregister_box(self)

# ---------- Movement ----------

func can_move(dir: Vector2i) -> bool:
	if moving or dir == Vector2i.ZERO:
		return false

	var new_anchor := grid_pos + dir

	for segment in segments:
		var cell: Vector2i = new_anchor + segment.offset
		if is_wall(cell):
			return false

		var other = level.get_box_at(cell)
		if other != null and other != self:
			# Foreign box – ask it whether it can be pushed
			if not other.can_move(dir):
				return false

	return true


func try_move(dir: Vector2i) -> bool:
	if not can_move(dir):
		return false

	# Push any foreign boxes first
	var new_anchor := grid_pos + dir
	for segment in segments:
		var cell: Vector2i = new_anchor + segment.offset
		var other = level.get_box_at(cell)
		if other != null and other != self:
			other.try_move(dir)

	# Move ourselves
	_do_move(dir)
	return true

func _do_move(dir: Vector2i) -> void:
	var target := grid_pos + dir
	moving = true

	level.unregister_box(self)
	grid_pos = target
	level.register_box(self)

	var tween := create_tween()
	tween.tween_property(self, "global_position", grid_to_world(grid_pos), 1.0 / move_speed)\
		.set_trans(Tween.TRANS_SINE)

	await tween.finished
	moving = false
	_on_move_finished()


# ---------- Helpers for Level / Signals ----------

func get_segment_at(cell: Vector2i) -> BoxSegment:
	var rel := cell - grid_pos
	for segment in segments:
		if segment.offset == rel:
			return segment
	return null


func get_truth() -> bool:
	# For now use the first segment (you can change this later)
	if segments.is_empty():
		return false
	return Operators.is_binary(segments[0].val) and segments[0].val.contains("1")
	
## Grow the box by one cell in a cardinal direction.
## Returns the new BoxSegment on success, or null on failure.
func extend(dir: Vector2i, new_val: String = "-1", new_op: String = "NONE") -> BoxSegment:
	if dir == Vector2i.ZERO or abs(dir.x) + abs(dir.y) != 1:
		push_warning("extend() only accepts unit cardinal directions")
		return null
	if moving:
		return null

	# Find the furthest existing segment in that direction
	var max_proj := -999999
	var extreme_offset := Vector2i.ZERO
	for segment in segments:
		var proj: int = segment.offset.x * dir.x + segment.offset.y * dir.y
		if proj > max_proj:
			max_proj = proj
			extreme_offset = segment.offset

	var new_offset := extreme_offset + dir
	var new_cell: Vector2i = grid_pos + new_offset

	# Refuse to grow into a wall or another box
	if is_wall(new_cell) or level.get_box_at(new_cell) != null:
		return null

	# Create the new segment
	var new_segment := SEGMENT_SCENE.instantiate()
	new_segment.offset = new_offset
	new_segment.val = new_val
	new_segment.op = new_op.to_upper()

	# Add to the box
	add_child(new_segment)
	segments.append(new_segment)

	# Position it correctly
	new_segment.global_position = grid_to_world(new_cell)

	# Update the Level registry
	level.unregister_box(self)
	level.register_box(self)

	# Let signals know the board changed
	if level.has_method("request_signal_update"):
		level.request_signal_update()

	return new_segment

func evaluate(inputs: Array[String]) -> Array[String]:
	# Simple version – uses the first segment.
	# Later you can make this cell-aware.
	if segments.is_empty():
		return inputs.duplicate()

	var s = segments[0]
	var output: Array[String] = []

	if s.val != "-1":
		if Operators.is_binary(s.val):
			output.append(s.val)
		return output

	if s.op != "NONE":
		var result := Operators.evaluate(s.op, inputs)
		if not result.is_empty():
			output.append(result)
		return output

	return inputs.duplicate()
