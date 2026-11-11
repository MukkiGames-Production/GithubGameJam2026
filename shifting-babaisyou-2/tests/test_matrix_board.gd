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

	# One step away from solved: the Solve button must finish it.
	board.state = Puzzle.shift_row(board.GOAL_STATE, 0, 1)
	board._rebuild()
	await board.play_solution()
	_check(Puzzle.is_solved(board.state, board.goal_word), "solve finishes the board")

	scene.queue_free()
