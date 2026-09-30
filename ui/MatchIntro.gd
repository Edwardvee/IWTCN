class_name MatchIntro
extends Control
## Presentación de inicio de partida al estilo de los juegos de móvil: cuenta atrás
## 3 · 2 · 1 y luego el grito "I WANT THAT CASTLE NOW!". Mientras dura, la
## partida está en fase COUNTDOWN (nada se simula) y esta capa bloquea el input.
## Al terminar emite `finished` y Main llama a GameManager.begin_play().
## El texto final es el nombre del juego y no se traduce.

signal finished

const COUNT_STEP: float = 0.85
const SHOUT_TIME: float = 1.5
const NUMBER_COLORS: Array[Color] = [Color(1.0, 0.42, 0.35), Color(1.0, 0.78, 0.3), Color(0.55, 0.9, 0.45)]
const SHOUT_TEXT: String = "I WANT THAT\nCASTLE NOW!"

var _label: Label = null
var _tween: Tween = null
var _done: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.06, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_constant_override("outline_size", 28)
	_label.add_theme_color_override("font_outline_color", Color(0.09, 0.07, 0.12))
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(_label)
	_label.resized.connect(func() -> void: _label.pivot_offset = _label.size * 0.5)
	_play.call_deferred()


func _process(_delta: float) -> void:
	# Un invitado que entra a una partida ya empezada no espera la cuenta atrás.
	if not _done and GameManager.match_state != null and GameManager.match_state.match_time > 1.0:
		_finish()


func _play() -> void:
	_label.pivot_offset = _label.size * 0.5
	_tween = create_tween()
	for number: int in [3, 2, 1]:
		_tween.tween_callback(_show_number.bind(number))
		_tween.tween_property(_label, "scale", Vector2.ONE, COUNT_STEP * 0.45).from(Vector2(1.9, 1.9)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_label, "modulate:a", 0.0, COUNT_STEP * 0.35).set_delay(COUNT_STEP * 0.2)
	_tween.tween_callback(_show_shout)
	_tween.tween_property(_label, "scale", Vector2.ONE, 0.32).from(Vector2(2.4, 2.4)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(SHOUT_TIME - 0.32 - 0.25)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.25)
	_tween.tween_callback(_finish)


func _show_number(number: int) -> void:
	# Un golpe de tambor de guerra, igual en el 3, el 2 y el 1.
	Sfx.play(&"drum")
	_label.text = str(number)
	_label.add_theme_font_size_override("font_size", 420)
	_label.add_theme_color_override("font_color", NUMBER_COLORS[3 - number])
	_label.modulate.a = 1.0


func _show_shout() -> void:
	_label.text = SHOUT_TEXT
	_label.add_theme_font_size_override("font_size", 132)
	_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	_label.modulate.a = 1.0
	UIFeedback.play_confirm()
	# La voz de la raza del jugador local grita el nombre del juego.
	var race: RaceData = GameManager.get_race(GameManager.local_player_id)
	if race != null:
		Sfx.play_intro(race.intro_sound)


func _finish() -> void:
	if _done:
		return
	_done = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	finished.emit()
	queue_free()
