extends MovingEntity

var inputs := {
	&"ui_right": Vector2i.RIGHT,
	&"ui_left":  Vector2i.LEFT,
	&"ui_up":    Vector2i.UP,
	&"ui_down":  Vector2i.DOWN,
}

var desired_dir: Vector2i = Vector2i.ZERO

func _unhandled_input(event: InputEvent) -> void:
	for action in inputs:
		if event.is_action_pressed(action):
			desired_dir = inputs[action]
			if not moving:
				try_move(desired_dir)
			return

		if event.is_action_released(action) and inputs[action] == desired_dir:
			desired_dir = Vector2i.ZERO
			return

func try_move(dir: Vector2i) -> bool:
	if not moving and not is_wall(grid_pos + dir) and _bump_shift_piece(dir):
		return false
	var success := await super.try_move(dir)
	
	# Keep moving while the key is held
	if success and desired_dir != Vector2i.ZERO and not moving:
		try_move(desired_dir)
	
	return success


## Shift pieces sit outside the wall grid as plain bodies. Cast one step ahead
## so walking into one cranks its line instead of passing through it.
func _bump_shift_piece(dir: Vector2i) -> bool:
	var ray: RayCast2D = $RayCast2D
	ray.target_position = grid_to_world(grid_pos + dir) - global_position
	ray.force_raycast_update()
	if not ray.is_colliding():
		return false
	var node := ray.get_collider() as Node
	while node != null:
		if node.has_method("push_from_player"):
			node.push_from_player(Vector2(dir), global_position)
			return true
		node = node.get_parent()
	return false

func _on_move_finished() -> void:
	level.check_win()
