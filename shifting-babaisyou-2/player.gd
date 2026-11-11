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
	var success := await super.try_move(dir)
	
	# Keep moving while the key is held
	if success and desired_dir != Vector2i.ZERO and not moving:
		try_move(desired_dir)
	
	return success

func _on_move_finished() -> void:
	level.check_win()
	if ray.is_colliding():
		_bump(ray.get_collider())
		return

	moving = true
	var target := position + desired_dir * tile_size

	var tween := create_tween()
	tween.tween_property(self, "position", target, 1.0 / move_speed)\
		.set_trans(Tween.TRANS_SINE)
	await tween.finished
	moving = false

	# Immediately try the next move if the player is still holding a direction
	try_move()


## Lets whatever we walked into react, e.g. the shift board shifting the row or
## column we are pushing against.
func _bump(collider: Object) -> void:
	var node := collider as Node
	while node != null:
		if node.has_method("push_from_player"):
			node.push_from_player(desired_dir, global_position)
			return
		node = node.get_parent()
