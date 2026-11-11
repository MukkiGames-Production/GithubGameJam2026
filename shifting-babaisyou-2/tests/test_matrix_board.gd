extends SceneTree
## Smoke test for the rendered board: loads Matrix_Puzzle.tscn, checks the
## sprite board builds, a drag-style move applies, undo restores it and the
## Solve path finishes the puzzle.
## Run with:
##   godot --headless --path . -s res://tests/test_matrix_board.gd

const Puzzle := preload("res://shift_puzzle.gd")

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


func _col_has_piece(state: String, col: int) -> bool:
	for row in 4:
		if state[row * 4 + col] != ".":
			return true
	return false


func _run() -> void:
	var packed: PackedScene = load("res://Matrix_Puzzle.tscn")
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
	_check(board.tiles[0].name.begins_with("Piece_"), "board reuses the pieces placed in the scene")
	_check(_count_floor(scene.get_node("Matrix")) == 16, "exactly the 16 scene floor tiles")
	_check(board.moves_made == 0, "new game starts at 0 moves")

	# Player integration: one board cell equals one player step.
	var player := scene.get_node_or_null("Player")
	_check(player != null, "player scene is instanced")
	if player == null:
		return
	var body := player.get_node_or_null("CharacterBody2D")
	_check(body != null, "player has its CharacterBody2D")
	if body == null:
		return
	_check(body.position == Vector2(32, 32), "player snapped onto the 64 px grid")
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

	# Shifting is done through the arrow pieces, not by bumping the board.
	_check(not board.has_method("push_from_player"), "board ignores direct bumps")
	var piece = null
	for node_name in ["ShiftPiece", "ShiftPiece2", "ShiftPiece3", "ShiftPiece4"]:
		var candidate = scene.get_node_or_null(node_name)
		if candidate != null and _col_has_piece(board.state, clampi(candidate.cell.x, 0, 3)):
			piece = candidate
			break
	if piece == null:
		piece = scene.get_node_or_null("ShiftPiece")
	_check(piece != null and piece.has_method("push_from_player"), "shift pieces are interactive")
	if piece == null:
		return
	_check(piece.global_position == board.to_global(board.cell_center(piece.cell)), "shift piece snapped onto the board grid")

	# The scene layout is free-form: make sure the crank's column has a piece.
	var piece_col: int = clampi(piece.cell.x, 0, 3)
	if not _col_has_piece(board.state, piece_col):
		for row in 4:
			if board.state[row * 4 + piece_col] == ".":
				board.tiles[0].position = board.cell_center(Vector2i(piece_col, row))
				break
		board.state = board._state_from_tiles()
	_check(_col_has_piece(board.state, piece_col), "shift piece column holds a piece")

	var before_push: String = board.state
	body.desired_dir = Vector2.DOWN
	body._bump(piece.get_node("Body/CollisionShape2D"))
	await create_timer(0.8).timeout
	_check(board.state == Puzzle.shift_col(before_push, piece_col, 1), "shift piece shifts its column downwards")

	# The Solve path runs the solver and lands the board solved.
	board.state = "1....O.........."
	_check(not Puzzle.is_solved(board.state, board.goal_word), "test layout is unsolved")
	await board.play_solution()
	_check(Puzzle.is_solved(board.state, board.goal_word), "solve finishes the board")

	scene.queue_free()
