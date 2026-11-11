class_name ShiftPiece
extends Sprite2D
## Arrow crank around the matrix. Bump into it and the board line it points at
## shifts in the arrow's own direction - the player's push direction is ignored.

## Where the line moves: RIGHT/LEFT shift a row, UP/DOWN shift a column.
@export var direction := Vector2i.RIGHT

## Sibling board to crank; defaults to a sibling named Matrix.
@export var board_path: NodePath = ^"../Matrix"

var cell := Vector2i.ZERO

# Untyped so this script does not depend on the global class cache at parse
# time (the board is found through board_path).
var _board
var _base_scale := Vector2.ONE


func _ready() -> void:
	_board = get_node_or_null(board_path)
	if _board == null or not _board.has_method("shift_line"):
		_board = null
		return
	_base_scale = scale
	# Sit exactly on the board grid, so hand-placed art never drifts off it.
	cell = _board.cell_at(_board.to_local(global_position))
	global_position = _board.to_global(_board.cell_center(cell))


func push_from_player(_push: Vector2, _from_position: Vector2) -> void:
	if _board == null or _board.busy:
		return
	_board.shift_line(cell, Vector2(direction))
	_press()


func _press() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", _base_scale * 0.82, 0.06)
	tween.tween_property(self, "scale", _base_scale, 0.14)
