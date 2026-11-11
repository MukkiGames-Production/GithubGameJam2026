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
