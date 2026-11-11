extends SceneTree
## godot --headless --path . -s res://tests/test_signal_network.gd

var checks := 0
var failures := 0


func _initialize() -> void:
	await _run()
	print("Signal network: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + description)


func _run() -> void:
	var a: Array[String] = ["0010001"]
	_check(Operators.evaluate("NOT", a) == "1101110", "NOT keeps bit width")
	var pair: Array[String] = ["0010001", "111"]
	var expected := {"AND": "0000001", "OR": "0010111", "XOR": "0010110",
		"NAND": "1111110", "NOR": "1101000", "XNOR": "1101001"}
	for op in expected:
		_check(Operators.evaluate(op, pair) == expected[op], op + " pads unequal widths")
	_check(Operators.evaluate("<<", a) == "0100010", "left shift defaults to one")
	_check(Operators.evaluate(">>", a) == "0001000", "right shift defaults to one")
	var shift: Array[String] = ["1011", "10"]
	_check(Operators.evaluate("<<", shift) == "1100", "binary shift amount")
	shift[1] = "1111111111111111111111111111111111111111111111111111111111111111111"
	_check(Operators.evaluate(">>", shift) == "0000", "large shifts clamp without overflow")
	var three: Array[String] = ["111", "110", "101"]
	_check(Operators.evaluate("NAND", three) == "011", "NAND inverts after reducing all inputs")
	var invalid: Array[String] = ["hello"]
	_check(Operators.evaluate("NOT", invalid).is_empty(), "invalid binary rejected")
	_check(Operators.evaluate("AND", a).is_empty(), "incomplete AND has no output")
	_check(Operators.evaluate("NOT", pair).is_empty(), "ambiguous NOT inputs rejected")
	var scene: Node2D = load("res://player_move_scene2.tscn").instantiate()
	root.add_child(scene)
	var level := scene.get_node("Level")
	await process_frame
	await process_frame
	var source: SignalTile = level.get_node("SourceA")
	var source_b: SignalTile = level.get_node("SourceB")
	var output_tile: SignalTile = level.get_node("OutputTile")
	var box: Box = level.get_node("Boxes/Box1")
	var zero_box: Box = level.get_node("Boxes/Box0")
	var gate = level.get_node("Gate")
	var original: Node2D = load("res://test_world.tscn").instantiate()
	var original_walls: TileMapLayer = original.get_node("Level/Walls")
	var walls: TileMapLayer = level.get_node("Walls")
	_check(walls.tile_set.tile_size == original_walls.tile_set.tile_size
		and walls.scale == original_walls.scale, "scene2 matches original tile size and layer scale")
	original.free()
	var step: Vector2 = player_step(box)
	_check(step == Vector2(32, 0), "scaled TileMap advances 32 pixels per cell")
	var sprite: Sprite2D = box.get_node("Sprite2D")
	_check(is_equal_approx(sprite.texture.get_width() * sprite.global_scale.x, step.x),
		"box sprite fills exactly one tile")
	var player_sprite: Sprite2D = level.get_node("Player/Sprite2D")
	_check(is_equal_approx(player_sprite.texture.get_width() * player_sprite.global_scale.x, step.x),
		"player sprite fills exactly one tile")
	_check(box.global_position - level.get_node("Player").global_position == Vector2(0, 32),
		"player starts adjacent to box without a gap")
	_check(box.get_val_or_op() == "1", "box returns value")
	_check(zero_box.get_val_or_op() == "0", "zero box returns value")
	_check(source.output_values == ["1"], "source uses box above its cell")
	_check(output_tile.output_values == ["1", "0"], "two sources merge at output tile")
	_check(gate.is_open, "nonzero output opens gate")
	# Use the pulled player's shared grid movement and registry-based box pushing.
	var player = level.get_node("Player")
	var player_start: Vector2i = player.grid_pos
	_check(await player.try_move(Vector2i.DOWN), "player can push box through shared movement")
	await process_frame
	_check(player.grid_pos == player_start + Vector2i.DOWN, "player enters box's previous cell")
	_check(box.grid_pos == player_start + Vector2i.DOWN * 2, "box advances exactly one cell")
	_check(source.output_values.is_empty(), "player push moves box off source tile")
	await player.try_move(Vector2i.UP)
	await box.try_move(Vector2i.UP)
	await process_frame
	_check(source.output_values == ["1"], "pushed box can return to source")
	# One source can broadcast to multiple tiles; no box forwards every incoming string.
	var branch := SignalTile.new()
	branch.position = Vector2(608, 352)
	level.add_child(branch)
	source.destinations.append(branch)
	source_b.destinations.append(branch)
	level.recalculate_signals()
	_check(branch.output_values == ["1", "0"], "branch and empty-tile passthrough")
	source.destinations.append(output_tile)
	level.recalculate_signals()
	_check(output_tile.incoming_values.size() == 2, "duplicate links count once")
	# Changing a box's exported value triggers a deferred refresh.
	box.val = "0"
	await process_frame
	_check(output_tile.output_values == ["0", "0"] and not gate.is_open, "zero result closes gate")
	box.val = "1"
	await process_frame
	_check(gate.is_open, "restoring one reopens gate")
	# Move through the actual movement path; registry refresh clears dependent outputs.
	await box.try_move(Vector2i.RIGHT)
	await process_frame
	_check(source.output_values.is_empty(), "moving source clears old cell")
	_check(output_tile.output_values.is_empty(), "missing input clears downstream values")
	_check(not gate.is_open, "missing source keeps gate closed")
	await box.try_move(Vector2i.LEFT)
	await process_frame
	_check(output_tile.output_values == ["1", "0"], "moving box back restores graph")
	# Cycles terminate and remove any previously published result.
	output_tile.destinations.append(source)
	level.recalculate_signals()
	_check(source.output_values.is_empty() and output_tile.output_values.is_empty(), "cycles clear outputs")
	_check(not level.signal_errors.is_empty(), "cycle has a diagnostic")
	output_tile.destinations.clear()
	level.recalculate_signals()
	_check(output_tile.output_values == ["1", "0"], "removing cycle restores evaluation")
	box.queue_free()
	await process_frame
	await process_frame
	_check(source.output_values.is_empty(), "deleting source unregisters box")
	scene.queue_free()
	await process_frame


func player_step(entity: MovingEntity) -> Vector2:
	return entity.grid_to_world(entity.grid_pos + Vector2i.RIGHT) - entity.grid_to_world(entity.grid_pos)
