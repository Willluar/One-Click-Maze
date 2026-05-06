extends Control

@export_file("*.tscn") var game_scene_path: String = ""
@export_file("*.tscn") var options_scene_path: String = ""

@export var start_button_path: NodePath
@export var options_button_path: NodePath
@export var quit_button_path: NodePath

@export var normal_scale: Vector2 = Vector2(1.0, 1.0)
@export var highlighted_scale: Vector2 = Vector2(1.15, 1.15)

var start_button: Button
var options_button: Button
var quit_button: Button

var buttons: Array[Button] = []
var current_index: int = 0
var scan_timer: float = 0.0

func _ready() -> void:
	start_button = get_node_or_null(start_button_path) as Button
	options_button = get_node_or_null(options_button_path) as Button
	quit_button = get_node_or_null(quit_button_path) as Button

	if start_button == null:
		push_error("StartMenu.gd: start_button_path is invalid.")
	if options_button == null:
		push_error("StartMenu.gd: options_button_path is invalid.")
	if quit_button == null:
		push_error("StartMenu.gd: quit_button_path is invalid.")

	if start_button != null:
		start_button.pressed.connect(_on_start_pressed)
		buttons.append(start_button)

	if options_button != null:
		options_button.pressed.connect(_on_options_pressed)
		buttons.append(options_button)

	if quit_button != null:
		quit_button.pressed.connect(_on_quit_pressed)
		buttons.append(quit_button)

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

func _on_start_pressed() -> void:
	if game_scene_path.is_empty():
		push_error("StartMenu.gd: game_scene_path not assigned.")
		return

	var err := get_tree().change_scene_to_file(game_scene_path)
	if err != OK:
		push_error("StartMenu.gd: failed to load game scene: " + game_scene_path)

func _on_options_pressed() -> void:
	if options_scene_path.is_empty():
		push_error("StartMenu.gd: options_scene_path not assigned.")
		return

	var err := get_tree().change_scene_to_file(options_scene_path)
	if err != OK:
		push_error("StartMenu.gd: failed to load options scene: " + options_scene_path)

func _on_quit_pressed() -> void:
	get_tree().quit()
