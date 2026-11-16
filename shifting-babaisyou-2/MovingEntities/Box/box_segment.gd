extends Node2D
class_name BoxSegment

## Offset from the parent Box’s anchor (grid_pos)
@export var offset: Vector2i = Vector2i.ZERO

@export var val: String = "-1"
@export var op: String = "NONE"

@onready var box: Box = get_parent() as Box

func _ready() -> void:
	# Snap visual to the correct world position once the parent Box has its grid_pos
	if box and box.level:
		global_position = box.grid_to_world(box.grid_pos + offset)
