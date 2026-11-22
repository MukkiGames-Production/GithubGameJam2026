extends Node2D
class_name World

@export var levels: Array[PackedScene] = []
var current_level_index := 0
var current_level: Node = null

func _ready() -> void:
	load_level(current_level_index)

func load_level(index: int) -> void:
	if index >= levels.size():
		print("You beat the game!")
		return
		
	current_level_index = index
	current_level = levels[index].instantiate()
	add_child(current_level)
	current_level.level_completed.connect(_on_level_completed)

func _on_level_completed() -> void:
	current_level.queue_free()
	await get_tree().process_frame
	# You can play a sound or fade the screen here before loading the next one
	load_level(current_level_index + 1)
