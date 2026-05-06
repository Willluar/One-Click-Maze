extends CanvasLayer
# If your UI root is not a CanvasLayer, change this line to match the root node type.

@export var tap_max_seconds: float = 0.25

# NodePaths
@export var game_path: NodePath
@export var scanner_ui_path: NodePath
@export var phase_label_path: NodePath
@export var timer_label_path: NodePath
@export var option_label_path: NodePath
@export var queue_label_path: NodePath
@export var level_label_path: NodePath
@export var win_screen_path: NodePath
@export var win_title_label_path: NodePath
@export var win_subtitle_label_path: NodePath

var game: Node
var scanner_ui: Control
var phase_label: Label
var timer_label: Label
var option_label: Label
var queue_label: Label
var level_label: Label
var win_screen: Control
var win_title_label: Label
var win_subtitle_label: Label

var options := ["UP", "RIGHT", "DOWN", "LEFT", "CONFIRM"]
var option_index: int = 0

var planning_enabled: bool = false
var scan_time: float = 0.0

var is_pressing: bool = false
var press_time: float = 0.0

func _ready() -> void:
	game = get_tree().get_first_node_in_group("game")
	scanner_ui = get_node_or_null(scanner_ui_path) as Control
	phase_label = get_node_or_null(phase_label_path) as Label
	timer_label = get_node_or_null(timer_label_path) as Label
	option_label = get_node_or_null(option_label_path) as Label
	queue_label = get_node_or_null(queue_label_path) as Label
	level_label = get_node_or_null(level_label_path) as Label
	win_screen = get_node_or_null(win_screen_path) as Control
	win_title_label = get_node_or_null(win_title_label_path) as Label
	win_subtitle_label = get_node_or_null(win_subtitle_label_path) as Label

	if game == null:
		push_error("UI.gd: game_path not set/invalid.")
	if scanner_ui == null:
		push_error("UI.gd: scanner_ui_path not set/invalid.")
	if phase_label == null:
		push_error("UI.gd: phase_label_path not set/invalid.")
	if timer_label == null:
		push_error("UI.gd: timer_label_path not set/invalid.")
	if option_label == null:
		push_error("UI.gd: option_label_path not set/invalid.")
	if queue_label == null:
		push_error("UI.gd: queue_label_path not set/invalid.")
	if level_label == null:
		push_error("UI.gd: level_label_path not set/invalid.")
	if win_screen == null:
		push_error("UI.gd: win_screen_path not set/invalid.")
	if win_title_label == null:
		push_error("UI.gd: win_title_label_path not set/invalid.")
	if win_subtitle_label == null:
		push_error("UI.gd: win_subtitle_label_path not set/invalid.")

	set_option(get_current_option_name())
	set_queue([])
	set_planning_enabled(false)
	hide_win_screen()

func _process(delta: float) -> void:
	if not planning_enabled:
		return

	var scan_interval: float = Settings.scan_interval

	scan_time += delta
	if scan_time >= scan_interval:
		scan_time = 0.0
		option_index = (option_index + 1) % options.size()
		set_option(get_current_option_name())

	if is_pressing:
		press_time += delta

func _unhandled_input(event: InputEvent) -> void:
	if not planning_enabled:
		return

	if event.is_action_pressed("switch"):
		is_pressing = true
		press_time = 0.0
	elif event.is_action_released("switch"):
		is_pressing = false

		if game == null:
			return

		if press_time <= tap_max_seconds:
			game.on_option_selected(get_current_option_name())
		else:
			game.on_hold_confirm()

func set_phase(text: String) -> void:
	if phase_label != null:
		phase_label.text = text

func set_timer(seconds_left: float) -> void:
	if timer_label != null:
		timer_label.text = "TIME: " + str(max(0, int(ceil(seconds_left))))

func set_option(text: String) -> void:
	if option_label != null:
		option_label.text = "SELECT: " + text

func set_queue(queue: Array[String]) -> void:
	if queue_label == null:
		return

	if queue.is_empty():
		queue_label.text = "QUEUE: (empty)"
	else:
		queue_label.text = "QUEUE: " + " ".join(queue)

func set_level(current_level: int, total_levels: int) -> void:
	if level_label != null:
		level_label.text = "LEVEL: " + str(current_level) + "/" + str(total_levels)

func set_planning_enabled(v: bool) -> void:
	planning_enabled = v
	is_pressing = false
	press_time = 0.0
	scan_time = 0.0

	if scanner_ui != null:
		scanner_ui.visible = true

	if planning_enabled:
		set_option(get_current_option_name())
	else:
		set_option("—")

func get_current_option_name() -> String:
	return options[option_index]

func show_win_screen(total_levels: int) -> void:
	if scanner_ui != null:
		scanner_ui.visible = false

	if win_screen != null:
		win_screen.visible = true

	if win_title_label != null:
		win_title_label.text = "YOU WIN"

	if win_subtitle_label != null:
		if total_levels == 1:
			win_subtitle_label.text = "You completed all " + str(total_levels) + " level."
		if total_levels != 1:
			win_subtitle_label.text = "You completed all " + str(total_levels) + " levels."
func hide_win_screen() -> void:
	if win_screen != null:
		win_screen.visible = false
