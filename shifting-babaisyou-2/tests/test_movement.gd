extends SceneTree
## Regression checks for the shared player/box movement pulled from main.

var checks := 0
var failures := 0


func _initialize() -> void:
	await _run()
	print("Movement: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + description)


func _run() -> void:
	var level = load("res://LevelManagement/level.gd").new()
	var walls := TileMapLayer.new()
	walls.tile_set = TileSet.new()
	walls.tile_set.tile_size = Vector2i(64, 64)
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(image)
	atlas.texture_region_size = Vector2i(64, 64)
	atlas.create_tile(Vector2i.ZERO)
	walls.tile_set.add_source(atlas, 0)
	level.add_child(walls)
	level.walls_layer = walls
	var player = load("res://MovingEntities/Player/player.tscn").instantiate()
	player.position = Vector2(96, 96)
	level.add_child(player)
	var boxes: Array[Box] = []
	for x in [2, 3]:
		var box: Box = load("res://MovingEntities/Box/Box.tscn").instantiate()
		box.position = Vector2(x * 64 + 32, 96)
		level.add_child(box)
		boxes.append(box)
	root.add_child(level)
	await process_frame
	_check(player.grid_pos == Vector2i(1, 1), "player finds level and correct cell")
	_check(player.global_position == Vector2(96, 96), "player snaps to TileMap cell center")
	walls.set_cell(Vector2i(4, 1), 0, Vector2i.ZERO)
	_check(not await player.try_move(Vector2i.RIGHT), "wall prevents pushing a box chain")
	_check(player.grid_pos == Vector2i(1, 1) and boxes[0].grid_pos == Vector2i(2, 1)
		and boxes[1].grid_pos == Vector2i(3, 1), "blocked chain leaves every entity in place")
	walls.erase_cell(Vector2i(4, 1))
	_check(player.can_move(Vector2i.RIGHT), "unblocked chain can move")
	_check(boxes[0].grid_pos == Vector2i(2, 1) and boxes[1].grid_pos == Vector2i(3, 1)
		and not boxes[0].moving and not boxes[1].moving, "can_move does not push boxes")
	_check(await player.try_move(Vector2i.RIGHT), "player pushes whole chain")
	_check(player.grid_pos == Vector2i(2, 1) and boxes[0].grid_pos == Vector2i(3, 1)
		and boxes[1].grid_pos == Vector2i(4, 1), "chain advances exactly one cell")
	_check(level.get_box_at(Vector2i(2, 1)) == null
		and level.get_box_at(Vector2i(3, 1)) == boxes[0]
		and level.get_box_at(Vector2i(4, 1)) == boxes[1], "box registry matches new cells")
	for box in boxes:
		_check(box.global_position == box.grid_to_world(box.grid_pos), "box lands at cell center")
	_check(not await player.try_move(Vector2i.ZERO), "zero direction does not move")
	# Real press/release events exercise the pulled player's continuous movement.
	await player.try_move(Vector2i.DOWN)
	var before: Vector2i = player.grid_pos
	var press := InputEventAction.new()
	press.action = &"ui_right"
	press.pressed = true
	player._unhandled_input(press)
	await create_timer(0.3).timeout
	var release := InputEventAction.new()
	release.action = &"ui_right"
	release.pressed = false
	player._unhandled_input(release)
	await create_timer(0.2).timeout
	_check(player.grid_pos.x >= before.x + 2, "holding input continues movement")
	var after_release: Vector2i = player.grid_pos
	await create_timer(0.2).timeout
	_check(player.grid_pos == after_release and not player.moving, "release stops after current step")
	level.queue_free()
	await process_frame
