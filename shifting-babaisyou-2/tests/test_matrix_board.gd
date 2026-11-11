extends SceneTree
## Smoke test for the rendered board: loads Matrix_Puzzle.tscn, checks the
## sprite board builds, a drag-style move applies, undo restores it and the
## Solve path finishes the puzzle.
## Run with:
##   godot --headless --path . -s res://tests/test_matrix_board.gd

const Puzzle := preload("res://MatrixPuzzle/shift_puzzle.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	await _run()
	print("MatrixPuzzle board: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		return
	failures += 1
	print("FAIL: " + what)


func _pieces(state: String) -> int:
	var count := 0
	for i in state.length():
		if state[i] != ".":
			count += 1
	return count


func _count_floor(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is Sprite2D and child.has_meta("floor"):
			count += 1
	return count


func _line_has_piece(state: String, is_row: bool, idx: int) -> bool:
	for i in 4:
		var cell := Vector2i(i, idx) if is_row else Vector2i(idx, i)
		if state[cell.y * 4 + cell.x] != ".":
			return true
	return false


func _run() -> void:
	var packed: PackedScene = load("res://MatrixPuzzle/Matrix_Puzzle.tscn")
	_check(packed != null, "scene loads")
	if packed == null:
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame

	var board = scene.get_node_or_null("Matrix")
	_check(board != null, "Matrix node is in the scene")
	if board == null:
		return

	_check(board.tiles.size() == _pieces(board.state), "one sprite per piece")
	_check(board.tiles[0].name.ends_with("_tile"), "board spawns a copy of each scene piece")
	var templates_hidden := true
	for child in scene.get_node("Matrix").get_children():
		if child is Sprite2D and child.is_in_group("PuzzlePiece") and child.visible:
			templates_hidden = false
	_check(templates_hidden, "piece templates are hidden after spawning")
	_check(_count_floor(scene.get_node("Matrix")) == 16, "exactly the 16 scene floor tiles")
	_check(board.moves_made == 0, "new game starts at 0 moves")

	# Player integration: one board cell equals one player step.
	var player := scene.get_node_or_null("Player")
	_check(player != null, "player scene is instanced")
	if player == null:
		return
	var body = player.get_node_or_null("Level/Player")
	if body == null and player.has_method("try_move"):
		body = player  # the board instances player.tscn directly
	_check(body != null, "player node resolved")
	if body == null:
		return
	var grid_offset: Vector2 = body.position - Vector2(32, 32)
	var on_grid := is_zero_approx(fmod(grid_offset.x, 64.0)) and is_zero_approx(fmod(grid_offset.y, 64.0))
	_check(on_grid, "player snapped onto the 64 px grid")
	_check(board.cell_size == 64.0, "board cells match the player grid")
	_check(scene.get_node_or_null("Matrix/BoardCollision") != null, "board has a collision body")

	# Move a row that actually holds a piece, then undo it.
	var row_with_piece := 0
	for i in board.state.length():
		if board.state[i] != ".":
			row_with_piece = i / 4
			break
	var before: String = board.state
	await board._do_move("row", row_with_piece, 1)
	_check(board.state != before, "row move changes the state")
	_check(board.moves_made == 1, "move counted")
	await board.undo()
	_check(board.state == before, "undo restores the state")
	_check(board.moves_made == 0, "undo clears the move count")

	# Shifting is done through the arrow pieces, in their own direction.
	_check(not board.has_method("push_from_player"), "board ignores direct bumps")
	var piece = null
	for node_name in ["ShiftUpPiece", "ShiftDownPiece", "ShiftLeftPiece", "ShiftRightPiece"]:
		piece = scene.get_node_or_null(node_name)
		if piece != null:
			break
	_check(piece != null and piece.has_method("push_from_player"), "shift pieces are interactive")
	if piece == null:
		return
	_check(piece.global_position == board.to_global(board.cell_center(piece.cell)), "shift piece snapped onto the board grid")

	# Work out the line the piece cranks, the same way MatrixPuzzle does.
	var dir: Vector2i = piece.direction
	var is_row: bool = dir.x != 0
	var line_idx: int
	if is_row:
		line_idx = piece.cell.y if piece.cell.y >= 0 and piece.cell.y < 4 else piece.cell.x
	else:
		line_idx = piece.cell.x if piece.cell.x >= 0 and piece.cell.x < 4 else piece.cell.y
	line_idx = clampi(line_idx, 0, 3)

	# The scene layout is free-form: make sure the crank's line has a piece.
	if not _line_has_piece(board.state, is_row, line_idx):
		for i in 4:
			var cell := Vector2i(i, line_idx) if is_row else Vector2i(line_idx, i)
			if board.state[cell.y * 4 + cell.x] == ".":
				board.tiles[0].position = board.cell_center(cell)
				break
		board.state = board._state_from_tiles()
	_check(_line_has_piece(board.state, is_row, line_idx), "crank line holds a piece")

	var before_push: String = board.state
	body.desired_dir = Vector2i.DOWN  # the push direction must not matter
	body._bump(piece.get_node("Body/CollisionShape2D"))
	await create_timer(0.8).timeout
	var expected: String = before_push
	if is_row:
		expected = Puzzle.shift_row(expected, line_idx, -int(signf(dir.x)))
	else:
		expected = Puzzle.shift_col(expected, line_idx, int(signf(dir.y)))
	_check(board.state == expected, "shift piece shifts its line in its own direction")

	# The Solve path runs the solver and lands the board solved.
	board.state = "1....O.........."
	_check(not Puzzle.is_solved(board.state, board.goal_word), "test layout is unsolved")
	await board.play_solution()
	_check(Puzzle.is_solved(board.state, board.goal_word), "solve finishes the board")

	scene.queue_free()
