extends PanelContainer
## Pantalla de fin de partida: VICTORIA / DERROTA / EMPATE desde el punto de
## vista del jugador local. Bloquea el input del juego y permite reiniciar.


var _title: Label = null
var _subtitle: Label = null
var _restart_button: Button = null
var _replay_button: Button = null
var _menu_button: Button = null


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
	_restart_button = _make_button("Jugar de nuevo", layout)
	_restart_button.pressed.connect(_on_restart_pressed)
	_replay_button = _make_button("Ver repetición", layout)
	_replay_button.pressed.connect(_on_replay_pressed)
	_menu_button = _make_button("Menú", layout)
	_menu_button.pressed.connect(_on_menu_pressed)
	EventBus.partida_terminada.connect(_on_partida_terminada)
	EventBus.partida_iniciada.connect(_on_partida_iniciada)


func _make_button(text: String, parent: Control) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(520.0, 130.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 48)
	parent.add_child(button)
	return button


func _make_label(font_size: int, parent: Control) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 12)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	parent.add_child(label)
	return label


func _on_partida_terminada(ganador_player_id: int) -> void:
	var mode: MatchTypes.GameMode = GameManager.game_mode
	var online_spectator: bool = mode == MatchTypes.GameMode.ONLINE and GameManager.is_watching()
	_restart_button.text = "Repetir" if mode == MatchTypes.GameMode.REPLAY else ("Nueva partida" if mode == MatchTypes.GameMode.SPECTATE else "Jugar de nuevo")
	# El espectador online solo puede salir; el invitado no graba.
	_restart_button.visible = not online_spectator
	_replay_button.visible = mode != MatchTypes.GameMode.REPLAY and GameManager.is_authority()
	_menu_button.visible = mode != MatchTypes.GameMode.ONLINE or online_spectator
	if GameManager.is_watching():
		_show_watch_result(ganador_player_id)
		visible = true
		return
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


## Espectador/repetición: no hay "tu castillo", se nombra el bando ganador.
func _show_watch_result(ganador_player_id: int) -> void:
	match ganador_player_id:
		MatchTypes.PLAYER_BOTTOM:
			_title.text = "GANA ABAJO"
			_title.add_theme_color_override("font_color", MatchTypes.team_color(MatchTypes.PLAYER_BOTTOM))
			_subtitle.text = "El castillo de arriba ha caído"
		MatchTypes.PLAYER_TOP:
			_title.text = "GANA ARRIBA"
			_title.add_theme_color_override("font_color", MatchTypes.team_color(MatchTypes.PLAYER_TOP))
			_subtitle.text = "El castillo de abajo ha caído"
		_:
			_title.text = "EMPATE"
			_title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			_subtitle.text = "Ambos castillos han caído"


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	visible = false


## VS AI: se recarga la escena y Main arranca una partida nueva.
## Online: se cierra la conexión y se vuelve al menú.
func _on_restart_pressed() -> void:
	var mode: MatchTypes.GameMode = GameManager.game_mode
	if mode == MatchTypes.GameMode.ONLINE:
		NetworkManager.close()
		get_tree().change_scene_to_file(NetworkManager.MENU_SCENE)
		return
	# VS IA y espectador empiezan otra partida; una repetición se vuelve a ver.
	GameManager.configure_next_match(mode, 0, MatchTypes.PLAYER_BOTTOM)
	get_tree().reload_current_scene()


func _on_replay_pressed() -> void:
	var data: ReplayData = ReplayData.load_from(GameManager.last_replay_path) if GameManager.last_replay_path != "" else null
	if data == null:
		_subtitle.text = "No hay repetición guardada"
		return
	GameManager.pending_replay = data
	GameManager.configure_next_match(MatchTypes.GameMode.REPLAY, data.get_seed(), MatchTypes.PLAYER_BOTTOM)
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	NetworkManager.close()
	get_tree().change_scene_to_file(NetworkManager.MENU_SCENE)
