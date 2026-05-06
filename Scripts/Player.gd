extends Node2D

@export var move_lerp_speed: float = 12.0
@export var ice_move_lerp_speed: float = 5.5
@export var arrive_distance: float = 0.5

# Collision feedback
@export var bump_distance: float = 8.0
@export var bump_speed: float = 18.0
@export var camera_shake_duration: float = 0.12
@export var camera_shake_strength: float = 4.0

var can_move: bool = false
var cam: Camera2D = null

func _ready() -> void:
	cam = get_node_or_null("Camera2D") as Camera2D

func set_can_move(v: bool) -> void:
	can_move = v

func execute_queue(queue: Array[String], step_time: float, maze: Node) -> void:
	for cmd in queue:
		if not can_move:
			return

		var direction: Vector2i = Vector2i.ZERO

		match cmd:
			"UP":
				direction = Vector2i(0, -1)
			"RIGHT":
				direction = Vector2i(1, 0)
			"DOWN":
				direction = Vector2i(0, 1)
			"LEFT":
				direction = Vector2i(-1, 0)
			_:
				direction = Vector2i.ZERO

		if direction == Vector2i.ZERO:
			continue

		if maze.is_ice_level():
			await _execute_ice_move(direction, step_time, maze)
		else:
			await _execute_normal_move(direction, step_time, maze)

func _execute_normal_move(direction: Vector2i, step_time: float, maze: Node) -> void:
	var current_cell: Vector2i = maze.world_to_cell(global_position)
	var next_cell: Vector2i = current_cell + direction

	if maze.is_blocked(next_cell):
		await _do_bump_feedback(direction)
		return

	var target_pos: Vector2 = maze.cell_to_world(next_cell)
	await _move_smooth_to(target_pos, move_lerp_speed)

	if step_time > 0.0:
		await get_tree().create_timer(step_time).timeout

func _execute_ice_move(direction: Vector2i, step_time: float, maze: Node) -> void:
	var current_cell: Vector2i = maze.world_to_cell(global_position)
	var next_cell: Vector2i = current_cell + direction
	var moved: bool = false

	# If immediately blocked, still give feedback
	if maze.is_blocked(next_cell):
		await _do_bump_feedback(direction)
		return

	while not maze.is_blocked(next_cell):
		var target_pos: Vector2 = maze.cell_to_world(next_cell)
		await _move_smooth_to(target_pos, ice_move_lerp_speed)
		moved = true

		current_cell = next_cell
		next_cell = current_cell + direction

		if not can_move:
			return

	# Hit a wall at the end of the slide
	if moved:
		await _do_bump_feedback(direction)

	if moved and step_time > 0.0:
		await get_tree().create_timer(step_time).timeout

func _move_smooth_to(target_pos: Vector2, speed: float) -> void:
	while can_move and global_position.distance_to(target_pos) > arrive_distance:
		var delta := get_process_delta_time()
		global_position = global_position.lerp(target_pos, 1.0 - exp(-speed * delta))
		await get_tree().process_frame

	if can_move:
		global_position = target_pos

func _do_bump_feedback(direction: Vector2i) -> void:
	var start_pos: Vector2 = global_position
	var bump_target: Vector2 = start_pos + Vector2(direction) * bump_distance

	_start_camera_shake(camera_shake_duration, camera_shake_strength)

	# Move slightly into the wall
	while can_move and global_position.distance_to(bump_target) > arrive_distance:
		var delta := get_process_delta_time()
		global_position = global_position.lerp(bump_target, 1.0 - exp(-bump_speed * delta))
		await get_tree().process_frame

	global_position = bump_target

	# Move back to original position
	while can_move and global_position.distance_to(start_pos) > arrive_distance:
		var delta := get_process_delta_time()
		global_position = global_position.lerp(start_pos, 1.0 - exp(-bump_speed * delta))
		await get_tree().process_frame

	global_position = start_pos

func _start_camera_shake(duration: float, strength: float) -> void:
	if cam == null:
		return
	_do_camera_shake(duration, strength)

func _do_camera_shake(duration: float, strength: float) -> void:
	if cam == null:
		return

	var original_offset: Vector2 = cam.offset
	var elapsed: float = 0.0

	while elapsed < duration:
		var delta := get_process_delta_time()
		elapsed += delta

		var x := randf_range(-strength, strength)
		var y := randf_range(-strength, strength)
		cam.offset = original_offset + Vector2(x, y)

		await get_tree().process_frame

	cam.offset = original_offset
