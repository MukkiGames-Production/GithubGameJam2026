class_name MatrixPuzzle
extends Node2D
## 2D matrix puzzle board drawn from gamejam2026spritesheet.png.
##
## Rules live in shift_puzzle.gd (no nodes); this node only renders, animates
## and handles input. Drag a row or column to shift it, or use the HUD.

signal moved(moves: int)
signal solved(moves: int)

const Puzzle := preload("res://shift_puzzle.gd")

const N := 4                        # must match ShiftPuzzle.N
const SHEET_CELL := 8.0             # sprite sheet frame size in pixels
const TILE_SCALE := 4.0             # 8 px art drawn at 32 px
const BOARD_ORIGIN := Vector2(224, 224)

# Atlas frames as (column, row) cells of the 8x8 sprite sheet.
const FRAME_ONE := Vector2i(0, 0)
const FRAME_ZERO := Vector2i(1, 0)
const FRAME_FLOOR := Vector2i(0, 3)
const FRAME_HOLE := Vector2i(1, 3)

# Puzzle symbol -> atlas frame. "." (empty) has no frame and is skipped.
const TILE_FRAMES := {
	"1": FRAME_ONE,
	"O": FRAME_ZERO,
}

# A solved layout for the sheet's pieces: "1O" adjacent on the top row.
const GOAL_STATE := "1O......O....1.."

@export var sprite_sheet: Texture2D = preload("res://gamejam2026spritesheet.png")
@export var goal_word := "1O"
@export var cell_size := SHEET_CELL * TILE_SCALE
@export var board_origin := BOARD_ORIGIN
@export var scramble_moves := 5
@export var solve_depth := 6

var state: String = GOAL_STATE
var busy := false
var moves_made := 0
var history: Array = []

var tiles: Array[Sprite2D] = []

var _dragging := false
var _drag_start := Vector2.ZERO
var _drag_cell := Vector2i.ZERO
var _hud: CanvasLayer
var _moves_label: Label
var _status_label: Label


func _ready() -> void:
	assert(N == Puzzle.N, "MatrixPuzzle.N must match ShiftPuzzle.N")
	clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_build_floor()
	_build_hud()
	new_game()


func _draw() -> void:
	# Drawing gives this node a rect; clip_children clips the sliding tiles
	# (and their wrap-around ghosts) to the board.
	draw_rect(_board_rect(), Color("0c112b"))


# --- board construction ----------------------------------------------------

func _board_rect() -> Rect2:
	return Rect2(board_origin, Vector2.ONE * cell_size * N)


func _cell_center(cell: Vector2i) -> Vector2:
	return board_origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func _cell_of(tile: Node2D) -> Vector2i:
	return Vector2i(((tile.position - board_origin) / cell_size).floor())


func _make_sprite(frame: Vector2i) -> Sprite2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = sprite_sheet
	atlas.region = Rect2(Vector2(frame) * SHEET_CELL, Vector2.ONE * SHEET_CELL)
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.scale = Vector2.ONE * (cell_size / SHEET_CELL)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite


func _build_floor() -> void:
	for i in N * N:
		var floor_tile := _make_sprite(FRAME_FLOOR)
		floor_tile.position = _cell_center(Vector2i(i % N, i / N))
		floor_tile.modulate = Color(0.6, 0.65, 0.6)
		add_child(floor_tile)


func _rebuild() -> void:
	for tile in tiles:
		tile.queue_free()
	tiles.clear()
	for i in N * N:
		var ch := state[i]
		if not TILE_FRAMES.has(ch):
			continue
		var tile := _make_sprite(TILE_FRAMES[ch])
		tile.position = _cell_center(Vector2i(i % N, i / N))
		add_child(tile)
		tiles.append(tile)


# --- game flow -------------------------------------------------------------

func new_game() -> void:
	if busy:
		return
	moves_made = 0
	history.clear()
	state = GOAL_STATE
	var guard := 100
	while Puzzle.is_solved(state, goal_word) and guard > 0:
		guard -= 1
		state = GOAL_STATE
		for _i in scramble_moves:
			var k := randi_range(1, N - 1)
			var idx := randi() % N
			state = Puzzle.shift_row(state, idx, k) if randf() < 0.5 else Puzzle.shift_col(state, idx, k)
	_rebuild()
	moved.emit(moves_made)


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
	_rebuild()


# --- animation -------------------------------------------------------------

func _animate(kind: String, idx: int, n: int) -> void:
	var horizontal := kind == "row"
	var tween: Tween = null
	var ghosts: Array[Sprite2D] = []
	for tile in tiles:
		var cell := _cell_of(tile)
		if (horizontal and cell.y != idx) or (not horizontal and cell.x != idx):
			continue
		if tween == null:
			tween = create_tween().set_parallel(true)
			tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		var along: int = cell.x if horizontal else cell.y
		var dest := along - n if horizontal else along + n
		var target := _cell_center(Vector2i(dest, cell.y) if horizontal else Vector2i(cell.x, dest))
		var axis := "position:x" if horizontal else "position:y"
		tween.tween_property(tile, axis, target.x if horizontal else target.y, 0.35)

		if dest < 0 or dest >= N:
			# The tile leaves one edge: a ghost enters from the opposite one.
			var offset := N if dest < 0 else -N
			var ghost := tile.duplicate() as Sprite2D
			add_child(ghost)
			ghosts.append(ghost)
			var start_cell := Vector2i(along + offset, cell.y) if horizontal else Vector2i(cell.x, along + offset)
			var end_cell := Vector2i(dest + offset, cell.y) if horizontal else Vector2i(cell.x, dest + offset)
			ghost.position = _cell_center(start_cell)
			var ghost_target := _cell_center(end_cell)
			tween.tween_property(ghost, axis, ghost_target.x if horizontal else ghost_target.y, 0.35)

	if tween != null:
		await tween.finished
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
