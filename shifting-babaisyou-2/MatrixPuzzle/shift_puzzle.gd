class_name ShiftPuzzle
## Pure shifting-puzzle rules. No nodes, no rendering, no scene state, so the
## solver can be unit-tested headless (see tests/test_shift_puzzle.gd).
##
## A state is a row-major string of N*N characters, "." being an empty cell.

const N := 4
const GOAL_WORD := "BCDF"

## A concrete layout that satisfies is_solved(): BCDF reads down column 2.
const GOAL_STATE := "AEBG..C...D...F."

## The starting layout from the design doc.
const START := "BAEGC.....D...F."


## Positive n shifts the row left, negative n shifts it right. Wraps around.
static func shift_row(s: String, r: int, n: int) -> String:
	var bytes := s.to_ascii_buffer()
	var row := bytes.slice(r * N, (r + 1) * N)
	for c in N:
		bytes[r * N + c] = row[posmod(c + n, N)]
	return bytes.get_string_from_ascii()


## Positive n shifts the column down, negative n shifts it up. Wraps around.
static func shift_col(s: String, c: int, n: int) -> String:
	var bytes := s.to_ascii_buffer()
	var col := PackedByteArray()
	for r in N:
		col.append(bytes[r * N + c])
	for r in N:
		bytes[r * N + c] = col[posmod(r - n, N)]
	return bytes.get_string_from_ascii()


## Applies one move entry, e.g. ["row", 1, 2].
static func apply_move(s: String, move: Array) -> String:
	return shift_row(s, move[1], move[2]) if move[0] == "row" else shift_col(s, move[1], move[2])


## True when any row or column contains goal as a contiguous run. With a
## goal as long as a line this is the same as "the line spells the goal".
static func is_solved(s: String, goal: String = GOAL_WORD) -> bool:
	for i in N:
		var row := s.substr(i * N, N)
		var col := ""
		for r in N:
			col += s[r * N + i]
		if row.contains(goal) or col.contains(goal):
			return true
	return false


## Breadth-first search, so the first solution found is a shortest one.
## Returns [["row"|"col", index, amount], ...], or [] when no solution exists
## within max_depth (also for an already solved start).
static func solve(start: String = START, max_depth := 6, goal: String = GOAL_WORD) -> Array:
	var prev: Dictionary = {}
	prev[start] = null
	var frontier: Array = [start]
	for _depth in max_depth:
		var next: Array = []
		for s in frontier:
			if is_solved(s, goal):
				return _path(prev, s)
			for i in N:
				for k in range(1, N):
					var row_shift := shift_row(s, i, k)
					if not prev.has(row_shift):
						prev[row_shift] = [s, ["row", i, k]]
						next.append(row_shift)
					var col_shift := shift_col(s, i, k)
					if not prev.has(col_shift):
						prev[col_shift] = [s, ["col", i, k]]
						next.append(col_shift)
		frontier = next
	for s in frontier:
		if is_solved(s, goal):
			return _path(prev, s)
	return []


static func _path(prev: Dictionary, s: String) -> Array:
	var moves: Array = []
	while prev[s] != null:
		var entry: Array = prev[s]
		moves.push_front(entry[1])
		s = entry[0]
	return moves
