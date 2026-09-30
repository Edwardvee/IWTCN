extends Control
## Menú principal: VS IA, espectador (IA vs IA), repeticiones, crear sala
## online (código) o unirse con un código.
## Solo configura y navega; la partida la arranca Main.

const MAIN_SCENE: String = "res://scenes/Main.tscn"
## Bandera del idioma actual en el selector (abajo a la derecha).
const FLAGS: Dictionary = {
	"es": preload("res://assets/ui/flag_es.svg"),
	"en": preload("res://assets/ui/flag_us.svg"),
}
## Cielo del menú según la dificultad de la IA: fácil con florecitas, normal el de
## siempre y difícil rojo y amenazante (tools/art/world.js).
const BACKGROUNDS: Dictionary = {
	AIDifficulty.Level.EASY: preload("res://assets/ui/menu_bg_easy.svg"),
	AIDifficulty.Level.NORMAL: preload("res://assets/ui/menu_bg.svg"),
	AIDifficulty.Level.HARD: preload("res://assets/ui/menu_bg_hard.svg"),
}

@onready var _code: LineEdit = %Address
@onready var _status: Label = %Status
@onready var _background: TextureRect = %Background


func _ready() -> void:
	%PlayAI.pressed.connect(_on_play_ai_pressed)
	%Spectate.pressed.connect(_on_spectate_pressed)
	# El botón es la bandera del idioma actual; al pulsarlo cambia al otro.
	%Language.icon = FLAGS[Localization.current_language]
	%Language.tooltip_text = Localization.LANGUAGE_NAMES[Localization.current_language]
	%Language.pressed.connect(_on_language_pressed)
	%Difficulty.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	%Difficulty.pressed.connect(_on_difficulty_pressed)
	_refresh_difficulty_button()
	%Replays.pressed.connect(_on_replays_pressed)
	%Host.pressed.connect(_on_host_pressed)
	%Join.pressed.connect(_on_join_pressed)
	%Watch.pressed.connect(_on_watch_pressed)
	_code.text_changed.connect(_on_code_changed)
	NetworkManager.status_changed.connect(_on_status_changed)
	%LocalIP.text = tr("Online: el anfitrión crea una sala y comparte el código.\nCon el código también puedes verla como espectador.")


func _on_play_ai_pressed() -> void:
	NetworkManager.close()
	# Antes de jugar se elige raza (5 s); el selector arranca la partida.
	RaceSelect.open(get_tree(), RaceSelect.Mode.VS_AI)


## Alterna Fácil → Normal → Difícil para la próxima partida contra la IA.
func _on_difficulty_pressed() -> void:
	GameManager.set_ai_difficulty(AIDifficulty.next_level(GameManager.ai_difficulty))
	_refresh_difficulty_button()


func _refresh_difficulty_button() -> void:
	%Difficulty.text = tr("Dificultad: %s") % AIDifficulty.display_name(GameManager.ai_difficulty)
	_background.texture = BACKGROUNDS[GameManager.ai_difficulty]


## Cambia el idioma y reconstruye el menú para que todo el texto se actualice.
func _on_language_pressed() -> void:
	Localization.toggle_language()
	get_tree().reload_current_scene()


func _on_spectate_pressed() -> void:
	NetworkManager.close()
	GameManager.configure_next_match(MatchTypes.GameMode.SPECTATE, 0, MatchTypes.PLAYER_BOTTOM)
	get_tree().change_scene_to_file(MAIN_SCENE)


## Lista de repeticiones guardadas en una capa por encima del menú.
func _on_replays_pressed() -> void:
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.custom_minimum_size = Vector2(860.0, 0.0)
	layout.add_theme_constant_override("separation", 20)
	center.add_child(layout)
	var title: Label = Label.new()
	title.text = tr("Repeticiones")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 60)
	layout.add_child(title)
	var replays: Array[Dictionary] = ReplayData.list_replays()
	if replays.is_empty():
		var empty: Label = Label.new()
		empty.text = tr("Aún no hay partidas grabadas.\nJuega una partida y aparecerá aquí.")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 34)
		layout.add_child(empty)
	for replay_meta: Dictionary in replays.slice(0, 8):
		var button: Button = Button.new()
		button.text = describe_replay(replay_meta)
		button.custom_minimum_size = Vector2(0.0, 110.0)
		button.add_theme_font_size_override("font_size", 32)
		button.pressed.connect(_on_replay_chosen.bind(str(replay_meta["path"])))
		layout.add_child(button)
	var close: Button = Button.new()
	close.text = tr("Cerrar")
	close.theme_type_variation = &"WoodButton"
	close.custom_minimum_size = Vector2(0.0, 110.0)
	close.add_theme_font_size_override("font_size", 40)
	close.pressed.connect(overlay.queue_free)
	layout.add_child(close)


static func describe_replay(replay_meta: Dictionary) -> String:
	var winner: int = int(replay_meta.get("winner", MatchTypes.NO_PLAYER))
	var local_player: int = int(replay_meta.get("local_player", MatchTypes.PLAYER_BOTTOM))
	var mode: int = int(replay_meta.get("mode", MatchTypes.GameMode.VS_AI))
	var result: String = TranslationServer.translate("Empate")
	if mode == MatchTypes.GameMode.SPECTATE:
		if winner == MatchTypes.PLAYER_BOTTOM:
			result = TranslationServer.translate("Gana abajo")
		elif winner == MatchTypes.PLAYER_TOP:
			result = TranslationServer.translate("Gana arriba")
	elif winner == local_player:
		result = TranslationServer.translate("Victoria")
	elif winner != MatchTypes.NO_PLAYER:
		result = TranslationServer.translate("Derrota")
	return "%s · %s · %s · %s" % [
		str(replay_meta.get("date", "?")).replace("T", " "),
		MatchTypes.game_mode_name(mode as MatchTypes.GameMode),
		HUD.format_time(float(replay_meta.get("duration", 0.0))),
		result,
	]


func _on_replay_chosen(path: String) -> void:
	var data: ReplayData = ReplayData.load_from(path)
	if data == null:
		_status.text = tr("No se pudo abrir la repetición")
		return
	NetworkManager.close()
	GameManager.pending_replay = data
	GameManager.configure_next_match(MatchTypes.GameMode.REPLAY, data.get_seed(), MatchTypes.PLAYER_BOTTOM)
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_host_pressed() -> void:
	NetworkManager.host()


func _on_join_pressed() -> void:
	NetworkManager.join(_code.text)


## Entra a la sala del código como espectador y mira la partida en directo.
func _on_watch_pressed() -> void:
	NetworkManager.spectate(_code.text)


func _on_code_changed(text: String) -> void:
	var upper: String = text.to_upper()
	if upper != text:
		var column: int = _code.caret_column
		_code.text = upper
		_code.caret_column = column


func _on_status_changed(message: String) -> void:
	_status.text = message
