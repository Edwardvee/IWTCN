class_name SpectatorBar
extends PanelContainer
## Barra inferior de los modos de solo mirar. Solo emite señales; Main las
## conecta con el reloj de juego o el ReplayPlayer.
##   LOCAL:  IA contra IA en este dispositivo → pausa, velocidad y salir.
##   REPLAY: repetición → además barra de progreso y reiniciar.
##   LIVE:   partida online en directo → solo salir (el tiempo lo lleva el anfitrión).

signal pause_toggled(paused: bool)
signal speed_selected(speed: float)
signal seek_requested(seconds: float)
signal restart_requested
signal exit_requested

enum Kind { LOCAL, REPLAY, LIVE }

const SPEEDS: Array[float] = [1.0, 2.0, 4.0, 8.0]
const BUTTON_HEIGHT: float = 96.0

var _pause_button: Button = null
var _speed_buttons: Array[Button] = []
var _slider: HSlider = null
var _time_label: Label = null
var _dragging_slider: bool = false
var _duration: float = 0.0


func _init(kind: Kind = Kind.LOCAL) -> void:
	var show_progress: bool = kind == Kind.REPLAY
	var show_controls: bool = kind != Kind.LIVE
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.08, 0.06, 0.95)
	style.border_color = Color(0.89, 0.66, 0.23)
	style.border_width_top = 4
	style.set_content_margin_all(14.0)
	add_theme_stylebox_override("panel", style)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	add_child(layout)
	if show_progress:
		var progress_row: HBoxContainer = HBoxContainer.new()
		progress_row.add_theme_constant_override("separation", 16)
		layout.add_child(progress_row)
		_slider = HSlider.new()
		_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_slider.custom_minimum_size = Vector2(0.0, 60.0)
		_slider.step = 0.1
		_slider.drag_started.connect(func() -> void: _dragging_slider = true)
		_slider.drag_ended.connect(_on_slider_drag_ended)
		progress_row.add_child(_slider)
		_time_label = Label.new()
		_time_label.add_theme_font_size_override("font_size", 30)
		_time_label.custom_minimum_size = Vector2(220.0, 0.0)
		_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		progress_row.add_child(_time_label)
	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	layout.add_child(button_row)
	if kind == Kind.LIVE:
		var live_label: Label = Label.new()
		live_label.text = tr("● EN DIRECTO")
		live_label.add_theme_font_size_override("font_size", 34)
		live_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
		live_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		live_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		live_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		button_row.add_child(live_label)
	if show_controls:
		_pause_button = _make_button(tr("Pausa"), button_row)
		_pause_button.toggle_mode = true
		_pause_button.toggled.connect(_on_pause_toggled)
		for speed: float in SPEEDS:
			var button: Button = _make_button("x%d" % int(speed), button_row)
			button.toggle_mode = true
			button.button_pressed = speed == 1.0
			button.pressed.connect(_on_speed_pressed.bind(speed))
			_speed_buttons.append(button)
	if show_progress:
		_make_button(tr("Reiniciar"), button_row).pressed.connect(func() -> void: restart_requested.emit())
	var exit_button: Button = _make_button(tr("Salir"), button_row)
	exit_button.pressed.connect(func() -> void: exit_requested.emit())


## Repetición: actualiza la barra con el tiempo actual (sin pelear con el dedo).
func set_progress(seconds: float, duration: float) -> void:
	if _slider == null:
		return
	_duration = duration
	_slider.max_value = maxf(duration, 0.1)
	if not _dragging_slider:
		_slider.set_value_no_signal(seconds)
	_time_label.text = "%s / %s" % [HUD.format_time(seconds), HUD.format_time(duration)]


## Vuelve a "1x, sin pausa" (al reiniciar una repetición, por ejemplo).
func reset_controls() -> void:
	if _pause_button == null:
		return
	_pause_button.set_pressed_no_signal(false)
	_pause_button.text = tr("Pausa")
	for index: int in _speed_buttons.size():
		_speed_buttons[index].set_pressed_no_signal(SPEEDS[index] == 1.0)


func _on_pause_toggled(paused: bool) -> void:
	_pause_button.text = tr("Seguir") if paused else tr("Pausa")
	pause_toggled.emit(paused)


func _on_speed_pressed(speed: float) -> void:
	for index: int in _speed_buttons.size():
		_speed_buttons[index].set_pressed_no_signal(SPEEDS[index] == speed)
	speed_selected.emit(speed)


func _on_slider_drag_ended(value_changed: bool) -> void:
	_dragging_slider = false
	if value_changed:
		seek_requested.emit(_slider.value)


func _make_button(text: String, parent: Control) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 34)
	parent.add_child(button)
	return button
