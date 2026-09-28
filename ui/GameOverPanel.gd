extends PanelContainer
## Pantalla de fin de partida: VICTORIA / DERROTA / EMPATE desde el punto de
## vista del jugador local. Bloquea el input del juego y permite reiniciar.


var _title: Label = null
var _subtitle: Label = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	add_theme_stylebox_override("panel", style)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 40)
	add_child(layout)
	_title = _make_label(110, layout)
	_subtitle = _make_label(40, layout)
	var restart: Button = Button.new()
	restart.text = "Jugar de nuevo"
	restart.custom_minimum_size = Vector2(520.0, 130.0)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.add_theme_font_size_override("font_size", 48)
	restart.pressed.connect(_on_restart_pressed)
	layout.add_child(restart)
	EventBus.partida_terminada.connect(_on_partida_terminada)
	EventBus.partida_iniciada.connect(_on_partida_iniciada)


func _make_label(font_size: int, parent: Control) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 12)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	parent.add_child(label)
	return label


func _on_partida_terminada(ganador_player_id: int) -> void:
	if ganador_player_id == MatchTypes.NO_PLAYER:
		_title.text = "EMPATE"
		_title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		_subtitle.text = "Ambos castillos han caído"
	elif ganador_player_id == GameManager.local_player_id:
		_title.text = "¡VICTORIA!"
		_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		_subtitle.text = "Has destruido el castillo enemigo"
	else:
		_title.text = "DERROTA"
		_title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
		_subtitle.text = "Tu castillo ha caído"
	visible = true


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	visible = false


## Reinicio limpio: se recarga la escena y Main arranca una partida nueva.
func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
