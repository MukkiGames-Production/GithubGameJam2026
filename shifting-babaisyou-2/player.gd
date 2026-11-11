extends Node2D

@export var tile_size: int = 64
@export var move_speed: float = 6.0

var inputs := {
	&"ui_right": Vector2.RIGHT,
	&"ui_left": Vector2.LEFT,
	&"ui_up": Vector2.UP,
	&"ui_down": Vector2.DOWN
}

var moving := false
var desired_dir: Vector2 = Vector2.ZERO   # The direction the player currently wants to go

@onready var ray: RayCast2D = $RayCast2D

func _ready() -> void:
	position = position.snapped(Vector2.ONE * tile_size) + Vector2.ONE * (tile_size / 2.0)
	ray.collide_with_areas = true

func _unhandled_input(event: InputEvent) -> void:
	# Update desired direction on press
	for action in inputs:
		if event.is_action_pressed(action):
			desired_dir = inputs[action]
			if not moving:
				try_move()
			return   # Newest press wins
	# Clear desired direction when the key is released (optional but feels cleaner)
	for action in inputs:
		if event.is_action_released(action) and inputs[action] == desired_dir:
			desired_dir = Vector2.ZERO
			return

func try_move() -> void:
	if desired_dir == Vector2.ZERO or moving:
		return

	ray.target_position = desired_dir * tile_size
	ray.force_raycast_update()

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


## Lets whatever we walked into react, e.g. a shift piece shifting its row or
## column.
func _bump(collider: Object) -> void:
	var node := collider as Node
	while node != null:
		if node.has_method("push_from_player"):
			node.push_from_player(desired_dir, global_position)
			return
		node = node.get_parent()
