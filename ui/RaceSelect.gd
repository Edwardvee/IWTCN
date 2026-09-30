class_name RaceSelect
extends Control
## Selector de raza antes de la partida, al estilo del selector de personajes de GTA:
## la raza elegida ocupa el centro en grande y las otras dos esperan abajo; al tocar una
## de ellas la rueda gira y cambia de sitio. Hay SECONDS segundos para decidir (cuenta
## atrás en un anillo); al acabar, o al pulsar "Elegir", la elección queda fijada.
##   VS_AI:        fija la raza y arranca la partida.
##   ONLINE_HOST:  fija la raza y espera a la del invitado (NetworkManager arranca).
##   ONLINE_GUEST: envía su raza al anfitrión y espera el aviso de inicio.

enum Mode { VS_AI, ONLINE_HOST, ONLINE_GUEST }

const SCENE_PATH: String = "res://scenes/RaceSelect.tscn"
const MAIN_SCENE: String = "res://scenes/Main.tscn"
const SECONDS: float = 5.0

const CARD_SIZE: Vector2 = Vector2(620.0, 700.0)
const MAIN_CENTER_Y: float = 700.0
const SMALL_CENTER_Y: float = 1560.0
const SMALL_SCALE: float = 0.42
const SMALL_OFFSET_X: float = 300.0
const DEFAULT_CASTLE: Texture2D = preload("res://assets/structures/castle.svg")
const DEFAULT_CASTLE_TEAM: Texture2D = preload("res://assets/structures/castle_team.svg")

static var next_mode: Mode = Mode.VS_AI

var mode: Mode = Mode.VS_AI

var _races: Array[RaceData] = []
var _cards: Array[Control] = []
var _selected: int = 0
var _time_left: float = SECONDS
var _last_tick: int = -1
var _locked: bool = false
var _stage: Control = null
var _ring: Ring = null
var _name_label: Label = null
var _description_label: Label = null
var _special_label: Label = null
var _stats_label: RichTextLabel = null
var _confirm_button: Button = null
var _status_label: Label = null


## Abre el selector (cambia de escena) para el modo indicado.
static func open(tree: SceneTree, p_mode: Mode) -> void:
	next_mode = p_mode
	tree.change_scene_to_file(SCENE_PATH)


func _ready() -> void:
	mode = next_mode
	_races = GameManager.database.races
	for index: int in _races.size():
		if _races[index].id == GameManager.player_race:
			_selected = index
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_layout(false)
	_refresh_info()
	resized.connect(_layout.bind(false))


func _process(delta: float) -> void:
	# Online: si se cae la conexión no hay a quién esperar.
	if mode != Mode.VS_AI and not NetworkManager.has_connection():
		get_tree().change_scene_to_file(NetworkManager.MENU_SCENE)
		return
	if _locked:
		return
	_time_left = maxf(0.0, _time_left - delta)
	_ring.progress = _time_left / SECONDS
	_ring.text = str(ceili(_time_left))
	_ring.queue_redraw()
	var whole: int = ceili(_time_left)
	if whole != _last_tick:
		_last_tick = whole
		if whole > 0:
			Sfx.play(&"pop")
	if _time_left <= 0.0:
		lock_choice()


func _unhandled_input(event: InputEvent) -> void:
	if _locked:
		return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_left"):
		var step: int = 1 if event.is_action_pressed("ui_right") else -1
		select_race((_selected + step + _races.size()) % _races.size())
	elif event.is_action_pressed("ui_accept"):
		lock_choice()


func get_selected_race() -> RaceData:
	return _races[_selected]


func is_locked() -> bool:
	return _locked


## Pone a `index` en el centro de la rueda.
func select_race(index: int) -> void:
	if _locked or index == _selected or index < 0 or index >= _races.size():
		return
	_selected = index
	Sfx.play(&"pop")
	_layout(true)
	_refresh_info()


## Fija la raza elegida y sigue según el modo.
func lock_choice() -> void:
	if _locked:
		return
	_locked = true
	var race: RaceData = get_selected_race()
	GameManager.set_player_race(race.id)
	Sfx.play(&"unlock")
	_confirm_button.disabled = true
	_ring.progress = 0.0
	_ring.text = "✓"
	_ring.queue_redraw()
	match mode:
		Mode.VS_AI:
			get_tree().create_timer(0.7).timeout.connect(_start_vs_ai)
		Mode.ONLINE_HOST:
			_status_label.text = tr("Esperando al rival…")
			NetworkManager.host_race_locked(race.id)
		Mode.ONLINE_GUEST:
			_status_label.text = tr("Esperando al rival…")
			NetworkManager.guest_race_locked(race.id)


func _start_vs_ai() -> void:
	NetworkManager.close()
	GameManager.configure_next_match(MatchTypes.GameMode.VS_AI, 0, MatchTypes.PLAYER_BOTTOM)
	get_tree().change_scene_to_file(MAIN_SCENE)


func _leave() -> void:
	NetworkManager.close()
	get_tree().change_scene_to_file(NetworkManager.MENU_SCENE)


# --- Construcción ------------------------------------------------------------------------------------------

func _build_ui() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.05, 0.04, 0.09)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	for race: RaceData in _races:
		var card: Control = _make_card(race)
		_stage.add_child(card)
		_cards.append(card)
	var title: Label = Label.new()
	title.text = tr("Elige tu raza")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 40.0
	title.offset_bottom = 150.0
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	title.add_theme_color_override("font_outline_color", Color(0.09, 0.07, 0.12))
	title.add_theme_constant_override("outline_size", 22)
	add_child(title)
	_ring = Ring.new()
	_ring.custom_minimum_size = Vector2(150.0, 150.0)
	_ring.size = Vector2(150.0, 150.0)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)
	# Nombre, descripción, unidad especial y ajustes de la raza del centro.
	var info: VBoxContainer = VBoxContainer.new()
	info.name = "Info"
	info.add_theme_constant_override("separation", 10)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info)
	_name_label = _make_label(info, 64)
	_description_label = _make_label(info, 30)
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.custom_minimum_size = Vector2(880.0, 0.0)
	_special_label = _make_label(info, 32)
	_special_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_stats_label = RichTextLabel.new()
	_stats_label.bbcode_enabled = true
	_stats_label.fit_content = true
	_stats_label.scroll_active = false
	_stats_label.custom_minimum_size = Vector2(880.0, 0.0)
	_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_label.add_theme_font_size_override("normal_font_size", 30)
	_stats_label.add_theme_font_size_override("bold_font_size", 30)
	info.add_child(_stats_label)
	_confirm_button = Button.new()
	_confirm_button.text = tr("Elegir")
	_confirm_button.theme_type_variation = &"PrimaryButton"
	_confirm_button.custom_minimum_size = Vector2(560.0, 110.0)
	_confirm_button.add_theme_font_size_override("font_size", 52)
	_confirm_button.pressed.connect(lock_choice)
	add_child(_confirm_button)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 40)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(_status_label)
	var leave: Button = Button.new()
	leave.text = tr("Salir")
	leave.theme_type_variation = &"StoneButton"
	leave.custom_minimum_size = Vector2(190.0, 84.0)
	leave.position = Vector2(24.0, 24.0)
	leave.add_theme_font_size_override("font_size", 34)
	leave.pressed.connect(_leave)
	add_child(leave)


func _make_label(parent: Control, font_size: int) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 12)
	label.add_theme_color_override("font_outline_color", Color(0.09, 0.07, 0.12))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


## Tarjeta de una raza: su castillo, un soldado y su nombre, con el color de la raza.
func _make_card(race: RaceData) -> Control:
	var card: Panel = Panel.new()
	card.clip_contents = true
	card.size = CARD_SIZE
	card.pivot_offset = CARD_SIZE * 0.5
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = race.accent_color.darkened(0.72)
	style.set_corner_radius_all(40)
	style.set_border_width_all(10)
	style.border_color = race.accent_color
	style.shadow_color = Color(race.accent_color, 0.45)
	style.shadow_size = 30
	card.add_theme_stylebox_override("panel", style)
	# Los humanos no traen castillo propio: se usa el de siempre.
	var castle_art: Texture2D = race.castle_texture if race.castle_texture != null else DEFAULT_CASTLE
	var castle_team_art: Texture2D = race.castle_team_texture if race.castle_texture != null else DEFAULT_CASTLE_TEAM
	var castle: TextureRect = _make_texture(castle_art, Rect2(60.0, 90.0, 500.0, 430.0))
	card.add_child(castle)
	if castle_team_art != null:
		var team_layer: TextureRect = _make_texture(castle_team_art, Rect2(60.0, 90.0, 500.0, 430.0))
		team_layer.modulate = MatchTypes.team_color(MatchTypes.PLAYER_BOTTOM)
		card.add_child(team_layer)
	var soldier_data: UnitData = GameManager.database.get_unit(&"soldier")
	var frames: SpriteFrames = race.get_unit_frames(soldier_data)
	if frames != null:
		var soldier: TextureRect = _make_texture(frames.get_frame_texture(&"idle", 0), Rect2(210.0, 400.0, 200.0, 200.0))
		card.add_child(soldier)
	var label: Label = Label.new()
	label.text = tr(race.display_name)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -100.0
	label.offset_bottom = -20.0
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", race.accent_color.lightened(0.4))
	label.add_theme_color_override("font_outline_color", Color(0.09, 0.07, 0.12))
	label.add_theme_constant_override("outline_size", 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(label)
	card.gui_input.connect(_on_card_input.bind(_races.find(race)))
	return card


func _make_texture(texture: Texture2D, rect: Rect2) -> TextureRect:
	var picture: TextureRect = TextureRect.new()
	# Primero el modo de ajuste: si no, el tamaño del dibujo agranda el control.
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture = texture
	picture.position = rect.position
	picture.size = rect.size
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture


func _on_card_input(event: InputEvent, race_index: int) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		select_race(race_index)


# --- Rueda ----------------------------------------------------------------------------------------------

## Coloca las tarjetas: la elegida al centro y grande; las otras abajo, más pequeñas y
## apagadas. animate = giro suave entre posiciones.
func _layout(animate: bool) -> void:
	var center_x: float = size.x * 0.5
	var order: Array[int] = []
	for step: int in _races.size():
		order.append((_selected + step) % _races.size())
	for slot: int in order.size():
		var card: Control = _cards[order[slot]]
		var target_center: Vector2 = Vector2(center_x, MAIN_CENTER_Y)
		var target_scale: float = 1.0
		var target_tint: Color = Color.WHITE
		if slot > 0:
			var side: float = -1.0 if slot == 1 else 1.0
			target_center = Vector2(center_x + side * SMALL_OFFSET_X, SMALL_CENTER_Y)
			target_scale = SMALL_SCALE
			target_tint = Color(0.62, 0.62, 0.7)
		var target_position: Vector2 = target_center - CARD_SIZE * 0.5
		card.z_index = 10 - slot
		if animate:
			var tween: Tween = create_tween().set_parallel(true)
			tween.tween_property(card, "position", target_position, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "scale", Vector2.ONE * target_scale, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "modulate", target_tint, 0.3)
		else:
			card.position = target_position
			card.scale = Vector2.ONE * target_scale
			card.modulate = target_tint
	_ring.position = Vector2(center_x - 75.0, 160.0)
	var info: Control = get_node("Info")
	info.position = Vector2(center_x - 440.0, 1090.0)
	info.size = Vector2(880.0, 260.0)
	_confirm_button.position = Vector2(center_x - 280.0, size.y - 150.0)
	_status_label.position = Vector2(center_x - 400.0, size.y - 215.0)
	_status_label.size = Vector2(800.0, 60.0)


func _refresh_info() -> void:
	var race: RaceData = get_selected_race()
	_name_label.text = tr(race.display_name)
	_name_label.add_theme_color_override("font_color", race.accent_color.lightened(0.4))
	_description_label.text = tr(race.description)
	_special_label.text = ""
	for card: CardData in GameManager.database.cards:
		if card.required_race == race.id and card.unit != null:
			_special_label.text = tr("Unidad especial: %s") % tr(race.get_card_name(card))
	_stats_label.text = _stats_bbcode(race)


## Ajustes de la raza respecto a la base: "Vida +10 %" en verde o rojo.
func _stats_bbcode(race: RaceData) -> String:
	var lines: PackedStringArray = PackedStringArray()
	# [etiqueta, multiplicador, ¿más es mejor?]
	var entries: Array = [
		[tr("Vida"), race.hp_multiplier, true],
		[tr("Daño"), race.damage_multiplier, true],
		[tr("Cadencia"), race.attack_speed_multiplier, true],
		[tr("Velocidad"), race.move_speed_multiplier, true],
		[tr("Alcance"), race.attack_range_multiplier, true],
		[tr("Precio cartas"), race.unit_card_cost_multiplier, false],
		[tr("Ingresos"), race.income_multiplier, true],
	]
	for entry: Array in entries:
		var percent: int = roundi((float(entry[1]) - 1.0) * 100.0)
		if percent == 0:
			continue
		var good: bool = (percent > 0) == bool(entry[2])
		lines.append("[color=%s]%s %+d %%[/color]" % ["#7be36b" if good else "#ff7a6b", entry[0], percent])
	return "[center]%s[/center]" % "   ·   ".join(lines)


## Anillo con la cuenta atrás y el número de segundos.
class Ring:
	extends Control

	var progress: float = 1.0
	var text: String = str(ceili(RaceSelect.SECONDS))

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		draw_circle(center, 66.0, Color(0.09, 0.07, 0.12, 0.9))
		draw_arc(center, 66.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.15), 10.0)
		var color: Color = Color(1.0, 0.85, 0.3).lerp(Color(1.0, 0.35, 0.3), 1.0 - progress)
		draw_arc(center, 66.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, color, 10.0)
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 72
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, center + Vector2(-text_size.x * 0.5, text_size.y * 0.3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
