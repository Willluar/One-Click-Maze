extends Control

@export_file("*.tscn") var back_scene_path: String = ""

@export var min_scan_interval: float = 0.2
@export var max_scan_interval: float = 1.5
@export var scan_step: float = 0.1

@export var min_total_levels: int = 1
@export var max_total_levels: int = 20
@export var level_step: int = 1

@export var speed_value_path: NodePath
@export var slower_button_path: NodePath
@export var faster_button_path: NodePath

@export var level_value_path: NodePath
@export var fewer_levels_button_path: NodePath
@export var more_levels_button_path: NodePath

@export var back_button_path: NodePath

@export var normal_scale: Vector2 = Vector2(1.0, 1.0)
@export var highlighted_scale: Vector2 = Vector2(1.15, 1.15)

var speed_value: Label
var slower_button: Button
var faster_button: Button

var level_value: Label
var fewer_levels_button: Button
var more_levels_button: Button

var back_button: Button

var buttons: Array[Button] = []
var current_index: int = 0
var scan_timer: float = 0.0

func _ready() -> void:
	speed_value = get_node_or_null(speed_value_path) as Label
	slower_button = get_node_or_null(slower_button_path) as Button
	faster_button = get_node_or_null(faster_button_path) as Button

	level_value = get_node_or_null(level_value_path) as Label
	fewer_levels_button = get_node_or_null(fewer_levels_button_path) as Button
	more_levels_button = get_node_or_null(more_levels_button_path) as Button

	back_button = get_node_or_null(back_button_path) as Button

	if speed_value == null:
		push_error("OptionsMenu.gd: speed_value_path is invalid.")
	if slower_button == null:
		push_error("OptionsMenu.gd: slower_button_path is invalid.")
	if faster_button == null:
		push_error("OptionsMenu.gd: faster_button_path is invalid.")

	if level_value == null:
		push_error("OptionsMenu.gd: level_value_path is invalid.")
	if fewer_levels_button == null:
		push_error("OptionsMenu.gd: fewer_levels_button_path is invalid.")
	if more_levels_button == null:
		push_error("OptionsMenu.gd: more_levels_button_path is invalid.")

	if back_button == null:
		push_error("OptionsMenu.gd: back_button_path is invalid.")

	if slower_button != null:
		slower_button.pressed.connect(_on_slower_pressed)
		buttons.append(slower_button)

	if faster_button != null:
		faster_button.pressed.connect(_on_faster_pressed)
		buttons.append(faster_button)

	if fewer_levels_button != null:
		fewer_levels_button.pressed.connect(_on_fewer_levels_pressed)
		buttons.append(fewer_levels_button)

	if more_levels_button != null:
		more_levels_button.pressed.connect(_on_more_levels_pressed)
		buttons.append(more_levels_button)

	if back_button != null:
		back_button.pressed.connect(_on_back_pressed)
		buttons.append(back_button)

	_update_ui()
	_update_highlight()

func _process(delta: float) -> void:
	if buttons.is_empty():
		return

	scan_timer += delta
	if scan_timer >= Settings.scan_interval:
		scan_timer = 0.0
		current_index = (current_index + 1) % buttons.size()
		_update_highlight()

func _input(event: InputEvent) -> void:
	if buttons.is_empty():
		return

	if event.is_action_released("switch"):
		accept_event()
		var current_button: Button = buttons[current_index]
		if current_button != null:
			current_button.pressed.emit()

func _update_highlight() -> void:
	for i in range(buttons.size()):
		if buttons[i] == null:
			continue

		if i == current_index:
			buttons[i].scale = highlighted_scale
		else:
			buttons[i].scale = normal_scale

func _on_slower_pressed() -> void:
	Settings.scan_interval = clamp(
		Settings.scan_interval + scan_step,
		min_scan_interval,
		max_scan_interval
	)
	_update_ui()

func _on_faster_pressed() -> void:
	Settings.scan_interval = clamp(
		Settings.scan_interval - scan_step,
		min_scan_interval,
		max_scan_interval
	)
	_update_ui()

func _on_fewer_levels_pressed() -> void:
	Settings.total_levels = clamp(
		Settings.total_levels - level_step,
		min_total_levels,
		max_total_levels
	)
	_update_ui()

func _on_more_levels_pressed() -> void:
	Settings.total_levels = clamp(
		Settings.total_levels + level_step,
		min_total_levels,
		max_total_levels
	)
	_update_ui()

func _on_back_pressed() -> void:
	if back_scene_path.is_empty():
		push_error("OptionsMenu.gd: back_scene_path not assigned.")
		return

	var err := get_tree().change_scene_to_file(back_scene_path)
	if err != OK:
		push_error("OptionsMenu.gd: failed to load back scene: " + back_scene_path)

func _update_ui() -> void:
	if speed_value != null:
		speed_value.text = str(snapped(Settings.scan_interval, 0.01)) + "s"

	if level_value != null:
		level_value.text = str(Settings.total_levels)
