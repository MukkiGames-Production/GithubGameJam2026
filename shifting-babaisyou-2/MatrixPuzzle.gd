class_name MatrixPuzzle
extends Node2D
## 2D matrix puzzle board.
##
## Rules live in shift_puzzle.gd (no nodes); this node only renders, animates
## and handles input. The pieces are the sprites authored in the scene: the
## board reads its starting layout from them and never builds tiles at runtime.

signal moved(moves: int)
signal solved(moves: int)

const Puzzle := preload("res://shift_puzzle.gd")

const N := 4                        # must match ShiftPuzzle.N
const SHEET_CELL := 8.0             # sprite sheet frame size in pixels
const TILE_SCALE := 8.0             # 8 px art drawn at 64 px (one player cell)
const BOARD_ORIGIN := Vector2(192, 192)

@export var goal_word := "1O"
@export var cell_size := SHEET_CELL * TILE_SCALE
@export var board_origin := BOARD_ORIGIN
@export var solve_depth := 6

var state := ""
var busy := false
var moves_made := 0
var history: Array = []

var tiles: Array[Sprite2D] = []    # the piece sprites authored in the scene

var _start_cells: Dictionary = {}  # tile -> cell it was authored on

var _dragging := false
var _drag_start := Vector2.ZERO
var _drag_cell := Vector2i.ZERO
var _hud: CanvasLayer
var _moves_label: Label
var _status_label: Label


func _ready() -> void:
	assert(N == Puzzle.N, "MatrixPuzzle.N must match ShiftPuzzle.N")
	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_adopt_scene_sprites()
	_build_hud()
	new_game()


## Collects the sprite assets authored in the scene. Floors get aligned to the
## grid; pieces inside the board become the playable tiles.
func _adopt_scene_sprites() -> void:
	tiles.clear()
	_start_cells.clear()
	for child in get_children():
		if not child is Sprite2D:
			continue
		var sprite := child as Sprite2D
		if sprite.has_meta("floor"):
			sprite.scale = Vector2.ONE * (cell_size / SHEET_CELL)
			sprite.position = cell_center(sprite.get_meta("cell"))
		elif sprite.has_meta("symbol"):
			var cell := _cell_of(sprite)
			if cell.x < 0 or cell.x >= N or cell.y < 0 or cell.y >= N:
				continue  # spares or decorations outside the board are left alone
			sprite.scale = Vector2.ONE * (cell_size / SHEET_CELL)
			tiles.append(sprite)
			_start_cells[sprite] = cell


func _draw() -> void:
	# The drawn rect doubles as the alpha mask clip_children uses: tiles sliding
	# out of the board (and the ghosts entering it) are clipped to the board.
	draw_rect(_board_rect(), Color("0c112b"))


# --- board construction ----------------------------------------------------

func _board_rect() -> Rect2:
	return Rect2(board_origin, Vector2.ONE * cell_size * N)


func cell_center(cell: Vector2i) -> Vector2:
	return board_origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


## Board-space cell for a local position; cells outside the board are valid.
func cell_at(local_position: Vector2) -> Vector2i:
	var rel := local_position - board_origin
	return Vector2i(floori(rel.x / cell_size), floori(rel.y / cell_size))


func _cell_of(tile: Node2D) -> Vector2i:
	return Vector2i(((tile.position - board_origin) / cell_size).floor())


# --- game flow -------------------------------------------------------------

## Puts the pieces back where they were authored in the scene.
func new_game() -> void:
	if busy:
		return
	moves_made = 0
	history.clear()
	for tile in tiles:
		tile.position = cell_center(_start_cells[tile])
	state = _state_from_tiles()
	moved.emit(moves_made)


## Rebuilds the logical state from where the piece sprites currently are.
func _state_from_tiles() -> String:
	var cells := PackedStringArray()
	cells.resize(N * N)
	cells.fill(".")
	for tile in tiles:
		var cell := _cell_of(tile)
		cells[cell.y * N + cell.x] = String(tile.get_meta("symbol", ""))
	return "".join(cells)


func undo() -> void:
	if busy or history.is_empty():
		return
	var move: Array = history.pop_back()
	busy = true
	await _apply_move(move[0], move[1], N - move[2])
	moves_made -= 1
	moved.emit(moves_made)
	busy = false


func hint() -> void:
	if busy or Puzzle.is_solved(state, goal_word):
		return
	var moves: Array = Puzzle.solve(state, solve_depth, goal_word)
	if moves.is_empty():
		_status_label.text = "No solution within %d moves." % solve_depth
		return
	_flash_line(moves[0])


func play_solution() -> void:
	if busy or Puzzle.is_solved(state, goal_word):
		return
	var moves: Array = Puzzle.solve(state, solve_depth, goal_word)
	if moves.is_empty():
		_status_label.text = "No solution within %d moves." % solve_depth
		return
	busy = true
	for move in moves:
		await _apply_move(move[0], move[1], move[2])
		_record(move[0], move[1], move[2])
		await get_tree().create_timer(0.12).timeout
	busy = false
	if Puzzle.is_solved(state, goal_word):
		solved.emit(moves_made)
		_win_flash()


func _do_move(kind: String, idx: int, n: int) -> void:
	n = posmod(n, N)
	if busy or n == 0 or idx < 0 or idx >= N:
		return
	if not _line_has_piece(kind, idx):
		return  # shifting an empty line would just burn a move
	busy = true
	await _apply_move(kind, idx, n)
	_record(kind, idx, n)
	busy = false
	if Puzzle.is_solved(state, goal_word):
		solved.emit(moves_made)
		_win_flash()


## Shifts the board line aligned with cell in the direction of push. Called by
## the shift pieces around the board.
func shift_line(cell: Vector2i, push: Vector2) -> void:
	if busy or push == Vector2.ZERO:
		return
	if absf(push.x) > absf(push.y):
		_do_move("row", clampi(cell.y, 0, N - 1), -int(signf(push.x)))
	else:
		_do_move("col", clampi(cell.x, 0, N - 1), int(signf(push.y)))


func _line_has_piece(kind: String, idx: int) -> bool:
	for i in N:
		var ch := state[i * N + idx] if kind == "col" else state[idx * N + i]
		if ch != ".":
			return true
	return false


func _record(kind: String, idx: int, n: int) -> void:
	history.append([kind, idx, n])
	moves_made += 1
	moved.emit(moves_made)


func _apply_move(kind: String, idx: int, n: int) -> void:
	var anim_n := n
	if anim_n > N / 2:
		anim_n -= N  # take the short way around
	await _animate(kind, idx, anim_n)
	state = Puzzle.apply_move(state, [kind, idx, n])


# --- animation -------------------------------------------------------------

func _animate(kind: String, idx: int, n: int) -> void:
	var horizontal := kind == "row"
	var tween: Tween = null
	var ghosts: Array[Sprite2D] = []
	var landings: Array = []  # [tile, cell it ends on after wrapping]
	for tile in tiles:
		var cell := _cell_of(tile)
		if (horizontal and cell.y != idx) or (not horizontal and cell.x != idx):
			continue
		if tween == null:
			tween = create_tween().set_parallel(true)
			tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		var along: int = cell.x if horizontal else cell.y
		var dest := along - n if horizontal else along + n
		var target := cell_center(Vector2i(dest, cell.y) if horizontal else Vector2i(cell.x, dest))
		var axis := "position:x" if horizontal else "position:y"
		tween.tween_property(tile, axis, target.x if horizontal else target.y, 0.35)
		landings.append([tile, Vector2i(posmod(dest, N), cell.y) if horizontal else Vector2i(cell.x, posmod(dest, N))])

		if dest < 0 or dest >= N:
			# The tile leaves one edge: a ghost enters from the opposite one.
			var offset := N if dest < 0 else -N
			var ghost := tile.duplicate() as Sprite2D
			add_child(ghost)
			ghosts.append(ghost)
			var start_cell := Vector2i(along + offset, cell.y) if horizontal else Vector2i(cell.x, along + offset)
			var end_cell := Vector2i(dest + offset, cell.y) if horizontal else Vector2i(cell.x, dest + offset)
			ghost.position = cell_center(start_cell)
			var ghost_target := cell_center(end_cell)
			tween.tween_property(ghost, axis, ghost_target.x if horizontal else ghost_target.y, 0.35)

	if tween != null:
		await tween.finished
	for entry in landings:
		(entry[0] as Sprite2D).position = cell_center(entry[1])
	for ghost in ghosts:
		ghost.queue_free()


func _win_flash() -> void:
	for tile in tiles:
		var tween := tile.create_tween().set_loops(2)
		tween.tween_property(tile, "self_modulate", Color(2, 2, 2, 1), 0.15)
		tween.tween_property(tile, "self_modulate", Color.WHITE, 0.15)


func _flash_line(move: Array) -> void:
	for tile in tiles:
		var cell := _cell_of(tile)
		var on_line: bool = (move[0] == "row" and cell.y == move[1]) or (move[0] == "col" and cell.x == move[1])
		if not on_line:
			continue
		var tween := tile.create_tween().set_loops(3)
		tween.tween_property(tile, "self_modulate", Color(1.8, 1.8, 1.8, 1), 0.15)
		tween.tween_property(tile, "self_modulate", Color.WHITE, 0.15)


# --- input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			match key.keycode:
				KEY_R:
					new_game()
				KEY_U:
					undo()
				KEY_H:
					hint()
				KEY_S:
					play_solution()
		return

	if not event is InputEventMouseButton or busy:
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return

	var local := to_local(get_global_mouse_position())
	if mouse.pressed:
		if _board_rect().has_point(local):
			_dragging = true
			_drag_start = local
			_drag_cell = Vector2i(((local - board_origin) / cell_size).floor())
	else:
		_finish_drag(local)


func _finish_drag(local: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	var delta := local - _drag_start
	if delta.length() < cell_size * 0.4:
		return
	if absf(delta.x) > absf(delta.y):
		# Drag right shifts right, which is a negative left shift.
		_do_move("row", _drag_cell.y, -clampi(roundi(delta.x / cell_size), 1, N / 2))
	else:
		_do_move("col", _drag_cell.x, clampi(roundi(delta.y / cell_size), 1, N / 2))


# --- HUD -------------------------------------------------------------------

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)

	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	_hud.add_child(panel)

	var box := VBoxContainer.new()
	panel.add_child(box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	row.add_child(_button("New Game (R)", new_game))
	row.add_child(_button("Undo (U)", undo))
	row.add_child(_button("Hint (H)", hint))
	row.add_child(_button("Solve (S)", play_solution))

	_moves_label = Label.new()
	box.add_child(_moves_label)

	_status_label = Label.new()
	_status_label.modulate = Color("f8e757")
	box.add_child(_status_label)

	var help := Label.new()
	help.text = "Drag a row or column to shift it."
	help.add_theme_font_size_override("font_size", 12)
	help.modulate = Color(1, 1, 1, 0.6)
	box.add_child(help)

	moved.connect(_on_moved)
	solved.connect(_on_solved)


func _button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(handler)
	return button


func _on_moved(moves: int) -> void:
	_moves_label.text = "Moves: %d" % moves
	_status_label.text = ""


func _on_solved(moves: int) -> void:
	_moves_label.text = "Moves: %d" % moves
	_status_label.text = "Solved in %d moves!" % moves
