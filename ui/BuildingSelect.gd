class_name BuildingSelect
extends Control
## Selector de edificio modificador, justo después de elegir raza: 3 edificios al azar y
## un tiempo limitado para escoger uno (al acabar se fija el que esté marcado). Su efecto
## dura toda la partida (ver ModBuildings). Usa los mismos modos que RaceSelect:
##   VS_AI:        fija el edificio y arranca la partida.
##   ONLINE_HOST:  lo fija y espera al del invitado (NetworkManager arranca).
##   ONLINE_GUEST: lo envía al anfitrión y espera el aviso de inicio.

const SCENE_PATH: String = "res://scenes/BuildingSelect.tscn"
const MAIN_SCENE: String = "res://scenes/Main.tscn"
const SECONDS: float = 8.0

const CARD_HEIGHT: float = 400.0
const ICON_SIZE: float = 300.0
const SELECTED_SCALE: float = 1.03
const DIMMED: Color = Color(0.68, 0.68, 0.76)
const GOLD: Color = Color(1.0, 0.85, 0.35)

static var next_mode: RaceSelect.Mode = RaceSelect.Mode.VS_AI

var mode: RaceSelect.Mode = RaceSelect.Mode.VS_AI

var _choices: Array[StringName] = []
var _cards: Array[PanelContainer] = []
var _selected: int = 0
var _time_left: float = SECONDS
var _last_tick: int = -1
var _locked: bool = false
var _ring: RaceSelect.Ring = null
var _confirm_button: Button = null
var _status_label: Label = null


## Abre el selector (cambia de escena) para el modo indicado.
static func open(tree: SceneTree, p_mode: RaceSelect.Mode) -> void:
	next_mode = p_mode
	tree.change_scene_to_file(SCENE_PATH)


func _ready() -> void:
	mode = next_mode
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	_choices = ModBuildings.roll_choices(rng)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh_selection(false)


func _process(delta: float) -> void:
	# Online: si se cae la conexión no hay a quién esperar.
	if mode != RaceSelect.Mode.VS_AI and not NetworkManager.has_connection():
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
		if whole > 0 and whole <= 3:
			Sfx.play(&"pop")
	if _time_left <= 0.0:
		lock_choice()


func _unhandled_input(event: InputEvent) -> void:
	if _locked:
		return
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		select_index((_selected + 1) % _choices.size())
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		select_index((_selected - 1 + _choices.size()) % _choices.size())
	elif event.is_action_pressed("ui_accept"):
		lock_choice()


func get_choices() -> Array[StringName]:
	return _choices


func get_selected_id() -> StringName:
	return _choices[_selected]


func is_locked() -> bool:
	return _locked


func select_index(index: int) -> void:
	if _locked or index == _selected or index < 0 or index >= _choices.size():
		return
	_selected = index
	Sfx.play(&"pop")
	_refresh_selection(true)


## Fija el edificio marcado y sigue según el modo.
func lock_choice() -> void:
	if _locked:
		return
	_locked = true
	var building_id: StringName = get_selected_id()
	GameManager.player_mod = building_id
	Sfx.play(&"unlock")
	_confirm_button.disabled = true
	_ring.progress = 0.0
	_ring.text = "✓"
	_ring.queue_redraw()
	match mode:
		RaceSelect.Mode.VS_AI:
			get_tree().create_timer(0.7).timeout.connect(_start_vs_ai)
		RaceSelect.Mode.ONLINE_HOST:
			_status_label.text = tr("Esperando al rival…")
			NetworkManager.host_mod_locked(building_id)
		RaceSelect.Mode.ONLINE_GUEST:
			_status_label.text = tr("Esperando al rival…")
			NetworkManager.guest_mod_locked(building_id)


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
	var title: Label = Label.new()
	title.text = tr("Elige tu edificio")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 40.0
	title.offset_bottom = 150.0
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_outline_color", Color(0.09, 0.07, 0.12))
	title.add_theme_constant_override("outline_size", 22)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	_ring = RaceSelect.Ring.new()
	_ring.custom_minimum_size = Vector2(150.0, 150.0)
	_ring.size = Vector2(150.0, 150.0)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.text = str(ceili(SECONDS))
	add_child(_ring)
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Cards"
	column.add_theme_constant_override("separation", 30)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	for index: int in _choices.size():
		var card: PanelContainer = _make_card(_choices[index], index)
		column.add_child(card)
		_cards.append(card)
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
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_label)
	var leave: Button = Button.new()
	leave.text = tr("Salir")
	leave.theme_type_variation = &"StoneButton"
	leave.custom_minimum_size = Vector2(190.0, 84.0)
	leave.position = Vector2(24.0, 24.0)
	leave.add_theme_font_size_override("font_size", 34)
	leave.pressed.connect(_leave)
	add_child(leave)
	_layout()
	resized.connect(_layout)


func _layout() -> void:
	var center_x: float = size.x * 0.5
	_ring.position = Vector2(center_x - 75.0, 160.0)
	var column: Control = get_node("Cards")
	column.position = Vector2(70.0, 350.0)
	column.size = Vector2(size.x - 140.0, 0.0)
	_confirm_button.position = Vector2(center_x - 280.0, size.y - 150.0)
	_status_label.position = Vector2(center_x - 400.0, size.y - 215.0)
	_status_label.size = Vector2(800.0, 60.0)


## Tarjeta de un edificio: su dibujo a la izquierda, nombre y efecto a la derecha.
func _make_card(building_id: StringName, index: int) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, CARD_HEIGHT)
	card.pivot_offset = Vector2(470.0, CARD_HEIGHT * 0.5)
	card.add_theme_stylebox_override("panel", _card_style(false))
	card.gui_input.connect(_on_card_input.bind(index))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var picture: TextureRect = TextureRect.new()
	picture.texture = ModBuildings.icon(building_id)
	picture.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 14)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var name_label: Label = Label.new()
	name_label.text = ModBuildings.display_name(building_id)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 52)
	name_label.add_theme_color_override("font_color", GOLD)
	name_label.add_theme_color_override("font_outline_color", Color(0.09, 0.07, 0.12))
	name_label.add_theme_constant_override("outline_size", 12)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(name_label)
	var description_label: Label = Label.new()
	description_label.text = ModBuildings.description(building_id)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 34)
	description_label.add_theme_color_override("font_outline_color", Color(0.09, 0.07, 0.12))
	description_label.add_theme_constant_override("outline_size", 8)
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(description_label)
	return card


func _card_style(selected: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.12, 0.09, 0.96) if selected else Color(0.11, 0.09, 0.09, 0.92)
	style.set_corner_radius_all(34)
	style.set_border_width_all(10 if selected else 5)
	style.border_color = GOLD if selected else Color(0.45, 0.38, 0.28)
	style.set_content_margin_all(24.0)
	if selected:
		style.shadow_color = Color(GOLD, 0.4)
		style.shadow_size = 26
	return style


func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		select_index(index)


## Resalta la tarjeta marcada y apaga las demás.
func _refresh_selection(animate: bool) -> void:
	for index: int in _cards.size():
		var card: PanelContainer = _cards[index]
		var selected: bool = index == _selected
		card.add_theme_stylebox_override("panel", _card_style(selected))
		var target_scale: Vector2 = Vector2.ONE * (SELECTED_SCALE if selected else 1.0)
		var target_tint: Color = Color.WHITE if selected else DIMMED
		if animate:
			var tween: Tween = create_tween().set_parallel(true)
			tween.tween_property(card, "scale", target_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "modulate", target_tint, 0.18)
		else:
			card.scale = target_scale
			card.modulate = target_tint
