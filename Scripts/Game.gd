extends Node

enum Phase { PREVIEW, PLANNING, EXECUTION, WIN }

@export var preview_seconds: float = 6.0
@export var planning_seconds: float = 12.0
@export var execution_step_time: float = 0.18
@export var max_queue_len: int = 12

@export var level_size_increase: int = 1
@export var ice_every_n_levels: int = 2

@export var maze_path: NodePath
@export var player_path: NodePath
@export var ui_path: NodePath
@export var camera_path: NodePath

@export var zoom_preview: Vector2 = Vector2(1.0, 1.0)
@export var zoom_planning: Vector2 = Vector2(0.70, 0.70)
@export var zoom_execution: Vector2 = Vector2(1.25, 1.25)
@export var zoom_lerp_speed: float = 8.0

@export var debug_arrow_movement: bool = true
@export var debug_allowed_in_preview: bool = true
@export var debug_allowed_in_planning: bool = true
@export var debug_allowed_in_execution: bool = false

@onready var maze: Node = get_node_or_null(maze_path)
@onready var player: Node = get_node_or_null(player_path)
@onready var ui: Node = get_node_or_null(ui_path)
@onready var cam: Camera2D = get_node_or_null(camera_path) as Camera2D

var phase: Phase = Phase.PREVIEW
var phase_time_left: float = 0.0
var move_queue: Array[String] = []

var target_zoom: Vector2 = Vector2(1, 1)

var current_level: int = 1
var base_cells_w: int = 0
var base_cells_h: int = 0

func _ready() -> void:
	add_to_group("game")

	if maze == null:
		push_error("Game.gd: maze_path not set/invalid.")
		return
	if player == null:
		push_error("Game.gd: player_path not set/invalid.")
		return
	if ui == null:
		push_error("Game.gd: ui_path not set/invalid.")
		return
	if cam == null:
		push_error("Game.gd: camera_path not set/invalid.")

	await get_tree().process_frame

	base_cells_w = maze.cells_w
	base_cells_h = maze.cells_h

	current_level = 1
	_start_level(current_level)

	if cam != null:
		target_zoom = zoom_preview
		cam.zoom = target_zoom

func _process(delta: float) -> void:
	if cam != null:
		cam.zoom = cam.zoom.lerp(target_zoom, 1.0 - exp(-zoom_lerp_speed * delta))

	if phase == Phase.WIN:
		return

	phase_time_left -= delta
	ui.set_timer(phase_time_left)

	if phase_time_left <= 0.0:
		match phase:
			Phase.PREVIEW:
				start_planning()
			Phase.PLANNING:
				start_execution()
			Phase.EXECUTION:
				start_preview()

func _unhandled_input(event: InputEvent) -> void:
	if not debug_arrow_movement:
		return
	if phase == Phase.WIN:
		return
	if not (event is InputEventKey):
		return
	if not event.is_pressed():
		return
	if event.echo:
		return
	if not _debug_movement_allowed_in_current_phase():
		return

	if event.is_action_pressed("ui_up"):
		_try_debug_move(Vector2i(0, -1))
	elif event.is_action_pressed("ui_right"):
		_try_debug_move(Vector2i(1, 0))
	elif event.is_action_pressed("ui_down"):
		_try_debug_move(Vector2i(0, 1))
	elif event.is_action_pressed("ui_left"):
		_try_debug_move(Vector2i(-1, 0))

func _debug_movement_allowed_in_current_phase() -> bool:
	match phase:
		Phase.PREVIEW:
			return debug_allowed_in_preview
		Phase.PLANNING:
			return debug_allowed_in_planning
		Phase.EXECUTION:
			return debug_allowed_in_execution
		Phase.WIN:
			return false
	return false

func _try_debug_move(direction: Vector2i) -> void:
	var current_cell: Vector2i = maze.world_to_cell(player.global_position)

	if maze.is_ice_level():
		var next_cell: Vector2i = current_cell + direction
		var last_open_cell: Vector2i = current_cell

		while not maze.is_blocked(next_cell):
			last_open_cell = next_cell
			next_cell += direction

		if last_open_cell != current_cell:
			player.global_position = maze.cell_to_world(last_open_cell)
	else:
		var next_cell: Vector2i = current_cell + direction
		if maze.is_blocked(next_cell):
			return
		player.global_position = maze.cell_to_world(next_cell)

	if maze.is_player_on_exit(player.global_position):
		_complete_level()

func _start_level(level_number: int) -> void:
	var size_offset: int = (level_number - 1) * level_size_increase

	maze.cells_w = base_cells_w + size_offset
	maze.cells_h = base_cells_h + size_offset

	if ice_every_n_levels > 0 and level_number % ice_every_n_levels == 0:
		maze.set_level_type(maze.LevelType.ICE)
	else:
		maze.set_level_type(maze.LevelType.NORMAL)

	maze.generate_random_map()

	player.global_position = maze.get_start_world_pos()
	move_queue.clear()

	ui.hide_win_screen()
	ui.set_level(current_level, Settings.total_levels)

	start_preview()

func _complete_level() -> void:
	if current_level >= Settings.total_levels:
		final_win()
		return

	current_level += 1
	_start_level(current_level)

func start_preview() -> void:
	phase = Phase.PREVIEW
	phase_time_left = preview_seconds
	move_queue.clear()

	if maze.is_ice_level():
		ui.set_phase("PREVIEW: Ice level - movement slides")
	else:
		ui.set_phase("PREVIEW: Memorise the maze")

	ui.set_queue(move_queue)
	ui.set_level(current_level, Settings.total_levels)
	ui.set_planning_enabled(false)

	maze.show_maze(true)
	player.set_can_move(false)

	if cam != null:
		target_zoom = zoom_preview

func start_planning() -> void:
	phase = Phase.PLANNING
	phase_time_left = planning_seconds

	if maze.is_ice_level():
		ui.set_phase("PLANNING: Ice level - tap to queue slides")
	else:
		ui.set_phase("PLANNING: Tap to add moves, hold to confirm")

	ui.set_queue(move_queue)
	ui.set_level(current_level, Settings.total_levels)
	ui.set_planning_enabled(true)

	maze.show_maze(false)
	player.set_can_move(false)

	if cam != null:
		target_zoom = zoom_planning

func start_execution() -> void:
	phase = Phase.EXECUTION
	phase_time_left = 999999.0

	if maze.is_ice_level():
		ui.set_phase("EXECUTION: Sliding...")
	else:
		ui.set_phase("EXECUTION: Watch it play")

	ui.set_planning_enabled(false)
	ui.set_queue(move_queue)
	ui.set_level(current_level, Settings.total_levels)

	maze.show_maze(true)
	player.set_can_move(true)

	if cam != null:
		target_zoom = zoom_execution

	await player.execute_queue(move_queue, execution_step_time, maze)

	move_queue.clear()
	ui.set_queue(move_queue)

	if maze.is_player_on_exit(player.global_position):
		_complete_level()
	else:
		start_preview()

func final_win() -> void:
	phase = Phase.WIN

	move_queue.clear()

	ui.set_phase("")
	ui.set_timer(0.0)
	ui.set_option("—")
	ui.set_queue(move_queue)
	ui.set_level(Settings.total_levels, Settings.total_levels)
	ui.set_planning_enabled(false)
	ui.show_win_screen(Settings.total_levels)

	maze.show_maze(true)
	player.set_can_move(false)

	if cam != null:
		target_zoom = zoom_preview

func on_option_selected(option_name: String) -> void:
	if phase != Phase.PLANNING:
		return

	if option_name == "CONFIRM":
		start_execution()
		return

	if move_queue.size() >= max_queue_len:
		return

	move_queue.append(option_name)
	ui.set_queue(move_queue)

func on_hold_confirm() -> void:
	if phase == Phase.PLANNING:
		start_execution()
