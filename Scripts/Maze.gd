extends Node2D

enum LevelType { NORMAL, ICE }

@export var ground_layer_path: NodePath
@export var trees_layer_path: NodePath
@export var exit_marker_path: NodePath
@export var overlay_path: NodePath

# Maze size in "cells" (not tiles). Final tilemap size will be (cells*2+1).
@export var cells_w: int = 8
@export var cells_h: int = 8

# --- TILE SETTINGS ---
@export var floor_source_id: int = 0
@export var floor_atlas_coords: Vector2i = Vector2i(0, 0)
@export var floor_alt: int = 0

@export var wall_source_id: int = 0
@export var wall_atlas_coords: Vector2i = Vector2i(1, 0)
@export var wall_alt: int = 0

# Visual tint settings
@export var normal_ground_modulate: Color = Color(1, 1, 1, 1)
@export var normal_trees_modulate: Color = Color(1, 1, 1, 1)
@export var normal_exit_modulate: Color = Color(1, 1, 1, 1)

@export var ice_ground_modulate: Color = Color(0.7, 0.85, 1.2, 1)
@export var ice_trees_modulate: Color = Color(0.75, 0.9, 1.25, 1)
@export var ice_exit_modulate: Color = Color(0.8, 0.95, 1.3, 1)

var ground: TileMapLayer
var trees: TileMapLayer
var exit_marker: Node2D
var overlay: CanvasItem

var start_cell: Vector2i = Vector2i.ZERO
var exit_cell: Vector2i = Vector2i.ZERO

var tile_w: int
var tile_h: int

var current_level_type: LevelType = LevelType.NORMAL

func _ready() -> void:
	ground = get_node_or_null(ground_layer_path) as TileMapLayer
	trees = get_node_or_null(trees_layer_path) as TileMapLayer
	exit_marker = get_node_or_null(exit_marker_path) as Node2D
	overlay = get_node_or_null(overlay_path) as CanvasItem

	if ground == null:
		push_error("Maze.gd: ground_layer_path invalid or not a TileMapLayer.")
	if trees == null:
		push_error("Maze.gd: trees_layer_path invalid or not a TileMapLayer.")
	if exit_marker == null:
		push_error("Maze.gd: exit_marker_path invalid.")
	if overlay == null:
		push_error("Maze.gd: overlay_path invalid.")

	_apply_level_visuals()

func set_level_type(new_type: LevelType) -> void:
	current_level_type = new_type
	_apply_level_visuals()

func is_ice_level() -> bool:
	return current_level_type == LevelType.ICE

func generate_random_map(seed_value: int = -1) -> void:
	if ground == null:
		ground = get_node_or_null(ground_layer_path) as TileMapLayer
	if trees == null:
		trees = get_node_or_null(trees_layer_path) as TileMapLayer
	if exit_marker == null:
		exit_marker = get_node_or_null(exit_marker_path) as Node2D
	if overlay == null:
		overlay = get_node_or_null(overlay_path) as CanvasItem

	if ground == null or trees == null or exit_marker == null or overlay == null:
		push_error("Maze.gd: generate_random_map called before Maze nodes resolved. Check NodePaths.")
		return

	if seed_value == -1:
		randomize()
	else:
		seed(seed_value)

	tile_w = cells_w * 2 + 1
	tile_h = cells_h * 2 + 1

	ground.clear()
	trees.clear()

	for y in range(tile_h):
		for x in range(tile_w):
			_set_wall(Vector2i(x, y))

	var visited: Array = []
	visited.resize(cells_h)
	for y in range(cells_h):
		visited[y] = []
		visited[y].resize(cells_w)
		for x in range(cells_w):
			visited[y][x] = false

	var stack: Array[Vector2i] = []
	var start_cell_in_cells: Vector2i = Vector2i(0, 0)
	stack.append(start_cell_in_cells)
	visited[start_cell_in_cells.y][start_cell_in_cells.x] = true

	_carve_cell(start_cell_in_cells)

	while stack.size() > 0:
		var current: Vector2i = stack[stack.size() - 1]
		var neighbours: Array[Vector2i] = _unvisited_neighbours(current, visited)

		if neighbours.is_empty():
			stack.pop_back()
			continue

		var next: Vector2i = neighbours[randi() % neighbours.size()]

		_carve_between(current, next)
		_carve_cell(next)

		visited[next.y][next.x] = true
		stack.append(next)

	start_cell = _cell_to_tile(Vector2i(0, 0))
	exit_cell = _cell_to_tile(Vector2i(cells_w - 1, cells_h - 1))

	exit_marker.global_position = cell_to_world(exit_cell)
	_apply_level_visuals()

func show_maze(is_visible: bool) -> void:
	if overlay != null:
		overlay.visible = not is_visible

func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local_pos := ground.to_local(world_pos)
	return ground.local_to_map(local_pos)

func cell_to_world(cell: Vector2i) -> Vector2:
	var local_pos := ground.map_to_local(cell)
	return ground.to_global(local_pos)

func is_blocked(cell: Vector2i) -> bool:
	return trees.get_cell_source_id(cell) != -1

func is_player_on_exit(player_world_pos: Vector2) -> bool:
	return world_to_cell(player_world_pos) == exit_cell

func get_start_world_pos() -> Vector2:
	return cell_to_world(start_cell)

func _apply_level_visuals() -> void:
	if ground == null or trees == null or exit_marker == null:
		return

	if current_level_type == LevelType.ICE:
		ground.modulate = ice_ground_modulate
		trees.modulate = ice_trees_modulate
		exit_marker.modulate = ice_exit_modulate
	else:
		ground.modulate = normal_ground_modulate
		trees.modulate = normal_trees_modulate
		exit_marker.modulate = normal_exit_modulate

func _cell_to_tile(c: Vector2i) -> Vector2i:
	return Vector2i(c.x * 2 + 1, c.y * 2 + 1)

func _carve_cell(c: Vector2i) -> void:
	var t := _cell_to_tile(c)
	_set_floor(t)

func _carve_between(a: Vector2i, b: Vector2i) -> void:
	var ta := _cell_to_tile(a)
	var tb := _cell_to_tile(b)
	var mid := (ta + tb) / 2
	_set_floor(mid)

func _unvisited_neighbours(c: Vector2i, visited: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	for d: Vector2i in dirs:
		var n: Vector2i = c + d
		if n.x < 0 or n.y < 0 or n.x >= cells_w or n.y >= cells_h:
			continue
		if visited[n.y][n.x] == false:
			out.append(n)

	return out

func _set_floor(tile: Vector2i) -> void:
	ground.set_cell(tile, floor_source_id, floor_atlas_coords, floor_alt)
	trees.set_cell(tile, -1)

func _set_wall(tile: Vector2i) -> void:
	ground.set_cell(tile, floor_source_id, floor_atlas_coords, floor_alt)
	trees.set_cell(tile, wall_source_id, wall_atlas_coords, wall_alt)
