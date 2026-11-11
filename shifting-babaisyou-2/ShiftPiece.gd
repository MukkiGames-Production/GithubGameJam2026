class_name ShiftPiece
extends Sprite2D
## Arrow crank on the edge of the shift matrix. Bump into it and the board line
## it is aligned with shifts in the direction you pushed.
##
## Pieces above/below the board shift a column; pieces beside it shift a row, so
## you can add more of these around the board in the scene and they just work.

var axis := "col"  # "col" when above/below the board, "row" beside it
var cell := Vector2i.ZERO

## Sibling board to crank; defaults to a sibling named Matrix.
@export var board_path: NodePath = ^"../Matrix"

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
	axis = "col" if cell.x >= 0 and cell.x < _board.N else "row"


func push_from_player(push: Vector2, _from_position: Vector2) -> void:
	if _board == null or _board.busy:
		return
	var wants_column: bool = absf(push.y) > absf(push.x)
	if (axis == "col") != wants_column:
		return  # the player is on the wrong side to crank this piece
	_board.shift_line(cell, push)
	_press()


func _press() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", _base_scale * 0.82, 0.06)
	tween.tween_property(self, "scale", _base_scale, 0.14)
