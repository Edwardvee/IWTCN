class_name ShopPanel
extends PanelContainer
## Barra inferior: tienda de 3 cartas, reroll, oro y martillo.
##
## Solo presentación: muestra la oferta del jugador local (draft_ofrecido) y
## traduce gestos a llamadas del LocalInputController, que crea los comandos.
## Soltar una carta sobre la propia barra cancela el arrastre.

signal card_drag_started
signal card_drag_finished
## Mientras se arrastra una ESTRUCTURA: dónde está el puntero (active = false al soltar). Los
## iconos de los lados se vuelven transparentes cuando el puntero se acerca.
signal structure_drag_moved(screen_position: Vector2, active: bool)

var local_input: LocalInputController = null

const DICE: Texture2D = preload("res://assets/ui/dice.svg")
const COIN: Texture2D = preload("res://assets/ui/coin.svg")
const HAMMER: Texture2D = preload("res://assets/ui/hammer.svg")
const BUTTON_TEXT: Color = Color("3b2410")

var _card_views: Array[CardView] = []
var _drag_preview: PanelContainer = null
var _drag_style: StyleBoxFlat = null
var _drag_icon: TextureRect = null
var _drag_label: Label = null
var _reroll_cost_label: Label = null
## Carta que el jugador soltó por última vez (para sacudirla si se rechaza).
var _last_played_view: CardView = null
var _reroll_cost: int = 0
## Fondo de madera por defecto (el de la escena) para volver a él si la raza no trae uno.
var _default_panel_style: StyleBox = null

@onready var _card_row: HBoxContainer = %CardRow
@onready var _reroll_button: Button = %RerollButton
@onready var _hammer_button: Button = %HammerButton


func _ready() -> void:
	var offer_size: int = GameManager.get_rules().shop_offer_size if GameManager.get_rules() != null else 3
	for _index: int in offer_size:
		var view: CardView = CardView.new()
		view.drag_started.connect(_on_card_drag_started)
		view.drag_moved.connect(_on_card_drag_moved)
		view.drag_released.connect(_on_card_drag_released)
		_card_row.add_child(view)
		_card_views.append(view)
	_default_panel_style = get_theme_stylebox("panel")
	_create_drag_preview()
	_build_reroll_content()
	_hammer_button.icon = HAMMER
	_hammer_button.expand_icon = true
	_hammer_button.add_theme_constant_override("icon_max_width", 52)
	_hammer_button.add_theme_constant_override("h_separation", 10)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	_hammer_button.toggle_mode = true
	_hammer_button.toggled.connect(_on_hammer_toggled)
	EventBus.draft_ofrecido.connect(_on_draft_ofrecido)
	EventBus.oro_actualizado.connect(_on_oro_actualizado)
	EventBus.estructura_construida.connect(func(pid: int, _s: int, _d: StructureData, _l: int) -> void: _on_estructura_cambiada(pid))
	EventBus.estructura_fusionada.connect(func(pid: int, _a: int, _b: int, _l: int) -> void: _on_estructura_cambiada(pid))
	EventBus.estructura_vendida.connect(func(pid: int, _s: int, _g: int) -> void: _on_estructura_cambiada(pid))
	EventBus.coste_reroll_actualizado.connect(_on_coste_reroll_actualizado)
	EventBus.comando_rechazado.connect(_on_comando_rechazado)
	EventBus.partida_iniciada.connect(func(_mode: int, _seed: int) -> void: _apply_race_wood())
	_apply_race_wood()


## Madera de la barra según la raza del jugador: normal (humanos), oscura (goblins) o
## blanca (elfos). Cada raza la define en RaceData.shop_panel_texture.
func _apply_race_wood() -> void:
	var race: RaceData = GameManager.get_race(GameManager.local_player_id)
	var base_style: StyleBoxTexture = _default_panel_style as StyleBoxTexture
	if race == null or race.shop_panel_texture == null or base_style == null:
		add_theme_stylebox_override("panel", _default_panel_style)
		return
	var style: StyleBoxTexture = base_style.duplicate() as StyleBoxTexture
	style.texture = race.shop_panel_texture
	add_theme_stylebox_override("panel", style)


## Main llama a esto al conectar la escena.
func connect_input(input: LocalInputController) -> void:
	local_input = input
	local_input.hammer_mode_changed.connect(_on_hammer_mode_changed)


## Contenido del botón de reroll: dado, texto y precio con moneda.
func _build_reroll_content() -> void:
	_reroll_button.text = ""
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.offset_bottom = -3.0
	_reroll_button.add_child(row)
	row.add_child(_make_icon(DICE, 52.0))
	var title: Label = Label.new()
	title.text = tr("Reroll")
	_style_button_label(title)
	row.add_child(title)
	row.add_child(_make_icon(COIN, 36.0))
	_reroll_cost_label = Label.new()
	_style_button_label(_reroll_cost_label)
	row.add_child(_reroll_cost_label)


func _make_icon(texture: Texture2D, icon_size: float) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.texture = texture
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


func _style_button_label(label: Label) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", BUTTON_TEXT)
	label.add_theme_constant_override("outline_size", 0)


## Miniatura que sigue al dedo mientras se arrastra una carta.
func _create_drag_preview() -> void:
	_drag_preview = PanelContainer.new()
	_drag_preview.top_level = true
	_drag_preview.visible = false
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_style = StyleBoxFlat.new()
	_drag_style.bg_color = Color(0.13, 0.09, 0.07, 0.92)
	_drag_style.set_corner_radius_all(18)
	_drag_style.set_border_width_all(5)
	_drag_style.set_content_margin_all(8.0)
	_drag_style.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	_drag_style.shadow_size = 8
	_drag_style.shadow_offset = Vector2(0.0, 5.0)
	_drag_preview.add_theme_stylebox_override("panel", _drag_style)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	_drag_preview.add_child(row)
	_drag_icon = _make_icon(null, 72.0)
	row.add_child(_drag_icon)
	_drag_label = Label.new()
	_drag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_drag_label.add_theme_font_size_override("font_size", 32)
	row.add_child(_drag_label)
	add_child(_drag_preview)


func _refresh_affordability() -> void:
	var gold: int = EconomyManager.get_gold(GameManager.local_player_id)
	for view: CardView in _card_views:
		if view.card != null:
			var cost: int = EconomyManager.get_card_cost(GameManager.local_player_id, view.card)
			view.set_affordable(gold >= cost, maxi(0, cost - gold))
			view.refresh_name()
	_reroll_button.modulate = Color.WHITE if gold >= _reroll_cost else Color(1.0, 1.0, 1.0, 0.55)


# --- Arrastre --------------------------------------------------------------------

func _on_card_drag_started(view: CardView, screen_position: Vector2) -> void:
	if local_input == null:
		return
	_drag_label.text = tr(view.card.display_name)
	_drag_icon.texture = CardView.icon_for(view.card)
	_drag_style.border_color = CardView.type_color(view.card.card_type)
	_drag_preview.reset_size()
	_drag_preview.visible = true
	_move_preview(screen_position)
	local_input.begin_card_drag(view.card)
	card_drag_started.emit()
	if view.card.card_type == CardData.CardType.STRUCTURE:
		structure_drag_moved.emit(screen_position, true)


func _on_card_drag_moved(view: CardView, screen_position: Vector2) -> void:
	if local_input == null:
		return
	_move_preview(screen_position)
	local_input.update_card_drag(screen_position)
	if view.card.card_type == CardData.CardType.STRUCTURE:
		structure_drag_moved.emit(screen_position, true)


func _on_card_drag_released(view: CardView, screen_position: Vector2) -> void:
	if local_input == null:
		return
	_drag_preview.visible = false
	var cancelled: bool = get_global_rect().has_point(screen_position)
	_last_played_view = null if cancelled else view
	local_input.end_card_drag(view.offer_index, view.card, screen_position, cancelled)
	card_drag_finished.emit()
	structure_drag_moved.emit(screen_position, false)


func _move_preview(screen_position: Vector2) -> void:
	_drag_preview.global_position = screen_position - _drag_preview.size * 0.5 - Vector2(0.0, 80.0)


# --- Botones -------------------------------------------------------------------

func _on_reroll_pressed() -> void:
	GameManager.submit_command(RerollShopCommand.new(GameManager.local_player_id))


func _on_hammer_toggled(pressed: bool) -> void:
	if local_input != null:
		local_input.set_hammer_mode(pressed)


func _on_hammer_mode_changed(active: bool) -> void:
	_hammer_button.set_pressed_no_signal(active)
	_hammer_button.text = tr("Vender: toca") if active else tr("Martillo")


# --- Eventos -------------------------------------------------------------------

func _on_draft_ofrecido(player_id: int, cartas: Array[CardData]) -> void:
	if player_id != GameManager.local_player_id:
		return
	for index: int in _card_views.size():
		_card_views[index].set_card(index, cartas[index] if index < cartas.size() else null)
	_refresh_affordability()


func _on_oro_actualizado(player_id: int, _nuevo_total: int) -> void:
	if player_id == GameManager.local_player_id:
		_refresh_affordability()


func _on_estructura_cambiada(player_id: int) -> void:
	if player_id == GameManager.local_player_id:
		_refresh_affordability()


func _on_coste_reroll_actualizado(player_id: int, coste: int) -> void:
	if player_id == GameManager.local_player_id:
		_reroll_cost = coste
		_reroll_cost_label.text = "%d" % coste
		_refresh_affordability()


func _on_comando_rechazado(player_id: int, tipo_comando: StringName, _motivo: String) -> void:
	if player_id != GameManager.local_player_id:
		return
	if tipo_comando == &"play_card" and _last_played_view != null and _last_played_view.card != null:
		_last_played_view.play_reject()
		_last_played_view = null
	elif tipo_comando == &"reroll_shop":
		var tween: Tween = create_tween()
		var base_x: float = _reroll_button.position.x
		for offset: float in [-10.0, 10.0, -6.0, 6.0, 0.0]:
			tween.tween_property(_reroll_button, "position:x", base_x + offset, 0.04)
