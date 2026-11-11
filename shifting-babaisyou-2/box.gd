extends MovingEntity

func _ready() -> void:
	super._ready()
	add_to_group("boxes")

func can_move_to(target: Vector2i, _dir: Vector2i) -> bool:
	# Can't push into a wall or another box
	return not is_wall(target) and level.get_box_at(target) == null
