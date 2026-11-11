extends SceneTree
## Headless tests for the pure puzzle rules. No nodes involved.
## Run with:
##   godot --headless --path . -s res://tests/test_shift_puzzle.gd

const Puzzle := preload("res://shift_puzzle.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	_test_shift_row()
	_test_shift_col()
	_test_is_solved()
	_test_apply_move()
	_test_solver()
	_test_matrix_goal()
	_test_random_scrambles()
	print("ShiftPuzzle: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		return
	failures += 1
	print("FAIL: " + what)


func _test_shift_row() -> void:
	var s := "ABCD............"
	_check(Puzzle.shift_row(s, 0, 1) == "BCDA............", "shift_row left 1")
	_check(Puzzle.shift_row(s, 0, 3) == "DABC............", "shift_row left 3 wraps")
	_check(Puzzle.shift_row(s, 0, -1) == "DABC............", "shift_row right 1 wraps")
	_check(Puzzle.shift_row(s, 1, 2) == s, "empty row is unchanged")
	_check(Puzzle.shift_row(Puzzle.shift_row(s, 2, 2), 2, 2) == s, "shifting by 2 twice is identity")


func _test_shift_col() -> void:
	var s := "A...B...C...D..."
	_check(Puzzle.shift_col(s, 0, 1) == "D...A...B...C...", "shift_col down 1")
	_check(Puzzle.shift_col(s, 0, -1) == "B...C...D...A...", "shift_col up 1")
	_check(Puzzle.shift_col(s, 3, 1) == s, "empty column is unchanged")
	_check(Puzzle.shift_col(Puzzle.shift_col(s, 2, 1), 2, -1) == s, "opposite shifts cancel")


func _test_is_solved() -> void:
	_check(Puzzle.is_solved(Puzzle.GOAL_STATE), "GOAL_STATE is solved")
	_check(not Puzzle.is_solved(Puzzle.START), "START is not solved")
	_check(Puzzle.is_solved("BCDF............"), "goal word in a row")
	_check(Puzzle.is_solved("B...C...D...F..."), "goal word in a column")
	_check(not Puzzle.is_solved("B.C.D.F........."), "goal word must be contiguous")
	_check(Puzzle.is_solved("1O......O....1..", "1O"), "custom goal for the matrix board")


func _test_apply_move() -> void:
	var s := "ABCD............"
	_check(Puzzle.apply_move(s, ["row", 0, 1]) == Puzzle.shift_row(s, 0, 1), "apply_move row")
	_check(Puzzle.apply_move(s, ["col", 0, 1]) == Puzzle.shift_col(s, 0, 1), "apply_move col")


func _test_solver() -> void:
	var moves: Array = Puzzle.solve(Puzzle.START)
	_check(moves == [["row", 0, 2], ["row", 1, 2]], "shortest solution to START, got %s" % [moves])
	_check(Puzzle.is_solved(Puzzle.GOAL_STATE) and Puzzle.solve(Puzzle.GOAL_STATE).is_empty(),
			"already solved state returns no moves")


func _test_matrix_goal() -> void:
	var goal := "1O"
	var s := "1O......O....1.."
	_check(Puzzle.is_solved(s, goal), "matrix goal state is solved")
	var messed := Puzzle.shift_row(s, 0, 1)
	_check(not Puzzle.is_solved(messed, goal), "one shift breaks the goal")
	var moves: Array = Puzzle.solve(messed, 2, goal)
	_check(not moves.is_empty(), "matrix state is solvable")
	for move in moves:
		messed = Puzzle.apply_move(messed, move)
	_check(Puzzle.is_solved(messed, goal), "matrix solution applies")


func _test_random_scrambles() -> void:
	seed(2026)
	for trial in 20:
		var s: String = Puzzle.GOAL_STATE
		var applied := 0
		for _i in 3:
			applied += 1
			var k := randi_range(1, Puzzle.N - 1)
			var idx := randi() % Puzzle.N
			s = Puzzle.shift_row(s, idx, k) if randf() < 0.5 else Puzzle.shift_col(s, idx, k)
		if Puzzle.is_solved(s):
			continue
		var moves: Array = Puzzle.solve(s, 3)
		_check(not moves.is_empty(), "scramble is solvable within %d moves (trial %d)" % [applied, trial])
		_check(moves.size() <= applied, "solution is no longer than the scramble (trial %d)" % trial)
		for move in moves:
			s = Puzzle.apply_move(s, move)
		_check(Puzzle.is_solved(s), "solution applies to scramble (trial %d)" % trial)
