class_name CardView
extends PanelContainer
## Vista de una carta de la tienda. Solo presentación y gesto de arrastre:
## emite señales y ShopPanel decide qué hacer. Nunca ejecuta gameplay.
##
## Usa eventos de ratón: en móvil llegan emulados desde el táctil
## (emulate_mouse_from_touch), así hay un único camino para ambos.
## Mientras el botón sigue pulsado, Godot envía el movimiento a este control
## aunque el puntero salga de su rectángulo.
##
## El borde indica el tipo: estructuras amarillo, unidades azul, mejoras violeta.

signal drag_started(view: CardView, screen_position: Vector2)
signal drag_moved(view: CardView, screen_position: Vector2)
signal drag_released(view: CardView, screen_position: Vector2)

const DRAG_THRESHOLD: float = 12.0
## Ancho fijo: un 5 % menos que el que ocupaba al repartirse la fila entre 3.
const CARD_WIDTH: float = 319.0
const CARD_HEIGHT: float = 250.0
const TYPE_NAMES: Dictionary[int, String] = {
	CardData.CardType.STRUCTURE: "ESTRUCTURA",
	CardData.CardType.DIRECT_UNIT: "UNIDADES",
	CardData.CardType.GLOBAL_BUFF: "MEJORA",
}
const TYPE_COLORS: Dictionary[int, Color] = {
	CardData.CardType.STRUCTURE: Color("f5c231"),
	CardData.CardType.DIRECT_UNIT: Color("4c8dff"),
	CardData.CardType.GLOBAL_BUFF: Color("a768ff"),
}
const NAME_FONT_SIZE: int = 30
const NAME_MIN_FONT_SIZE: int = 20
const COIN: Texture2D = preload("res://assets/ui/coin.svg")
const OUTLINE: Color = Color(0.09, 0.07, 0.12)
const CREAM: Color = Color(1.0, 0.95, 0.83)

var offer_index: int = -1
var card: CardData = null

var _type_label: Label = null
var _name_label: Label = null
var _description_label: Label = null
var _cost_label: Label = null
var _missing_label: Label = null
var _icon: TextureRect = null
var _icon_team: TextureRect = null
var _icon_plate: StyleBoxFlat = null
var _type_style: StyleBoxFlat = null
var _style: StyleBoxFlat = null
var _pressed: bool = false
var _dragging: bool = false
var _press_position: Vector2 = Vector2.ZERO
var _press_tween: Tween = null


static func type_color(card_type: int) -> Color:
	return TYPE_COLORS.get(card_type, Color.WHITE)


## Icono de la carta: el suyo propio o, si es una estructura, su arte.
static func icon_for(card_data: CardData) -> Texture2D:
	if card_data == null:
		return null
	if card_data.icon != null:
		return card_data.icon
	if card_data.structure != null:
		return card_data.structure.texture
	return null


func _ready() -> void:
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.2, 0.13, 0.1)
	_style.set_corner_radius_all(20)
	_style.set_border_width_all(6)
	_style.set_content_margin_all(10.0)
	_style.content_margin_top = 8.0
	_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	_style.shadow_size = 8
	_style.shadow_offset = Vector2(0.0, 5.0)
	add_theme_stylebox_override("panel", _style)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 3)
	add_child(layout)

	var plate: PanelContainer = PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_icon_plate = StyleBoxFlat.new()
	_icon_plate.set_corner_radius_all(14)
	_icon_plate.set_content_margin_all(2.0)
	plate.add_theme_stylebox_override("panel", _icon_plate)
	layout.add_child(plate)
	_icon = _make_icon()
	plate.add_child(_icon)
	_icon_team = _make_icon()
	plate.add_child(_icon_team)

	_type_label = _make_label(17, plate)
	_type_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_type_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_type_label.add_theme_constant_override("outline_size", 0)
	_type_label.add_theme_color_override("font_color", OUTLINE)
	_type_style = StyleBoxFlat.new()
	_type_style.set_corner_radius_all(11)
	_type_style.content_margin_left = 14.0
	_type_style.content_margin_right = 14.0
	_type_style.content_margin_top = 0.0
	_type_style.content_margin_bottom = 0.0
	_type_label.add_theme_stylebox_override("normal", _type_style)

	_name_label = _make_label(NAME_FONT_SIZE, layout)
	_name_label.clip_text = true
	_description_label = _make_label(19, layout)
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.custom_minimum_size = Vector2(0.0, 46.0)
	_description_label.add_theme_color_override("font_color", Color(0.93, 0.88, 0.76))
	_description_label.add_theme_constant_override("outline_size", 4)
	_description_label.add_theme_constant_override("line_spacing", -2)

	var cost_badge: PanelContainer = PanelContainer.new()
	cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_badge.size_flags_horizontal = Control.SIZE_SHRINK_END
	cost_badge.size_flags_vertical = Control.SIZE_SHRINK_END
	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.09, 0.07, 0.12, 0.94)
	badge_style.set_corner_radius_all(18)
	badge_style.set_border_width_all(3)
	badge_style.border_color = Color(0.95, 0.76, 0.3)
	badge_style.content_margin_left = 6.0
	badge_style.content_margin_right = 12.0
	badge_style.content_margin_top = 0.0
	badge_style.content_margin_bottom = 0.0
	cost_badge.add_theme_stylebox_override("panel", badge_style)
	plate.add_child(cost_badge)
	var cost_row: HBoxContainer = HBoxContainer.new()
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.add_theme_constant_override("separation", 4)
	cost_badge.add_child(cost_row)
	var coin: TextureRect = TextureRect.new()
	coin.texture = COIN
	coin.custom_minimum_size = Vector2(32.0, 32.0)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost_row.add_child(coin)
	_cost_label = _make_label(30, cost_row)
	_missing_label = _make_label(18, cost_row)
	_missing_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	_missing_label.visible = false
	set_card(-1, null)


func set_card(p_offer_index: int, p_card: CardData) -> void:
	offer_index = p_offer_index
	card = p_card
	_cancel_gesture()
	visible = card != null
	scale = Vector2.ONE
	if card == null:
		return
	var color: Color = type_color(card.card_type)
	_type_label.text = tr(TYPE_NAMES.get(card.card_type, ""))
	_type_style.bg_color = color
	_name_label.text = tr(card.display_name)
	_fit_font(_name_label, NAME_FONT_SIZE, NAME_MIN_FONT_SIZE, CARD_WIDTH - 44.0)
	_description_label.text = tr(card.description)
	refresh_cost()
	_style.border_color = color
	_icon_plate.bg_color = color.darkened(0.62)
	_icon.texture = icon_for(card)
	# La capa de estandartes de una estructura lleva el color del bando local.
	var team_texture: Texture2D = card.structure.team_texture if card.structure != null else null
	_icon_team.texture = team_texture
	_icon_team.modulate = MatchTypes.team_color(GameManager.local_player_id)
	_icon_team.visible = team_texture != null


## Precio real para el jugador local (sube con cada copia construida).
func refresh_cost() -> void:
	if card != null:
		_cost_label.text = "%d" % EconomyManager.get_card_cost(GameManager.local_player_id, card)


func set_affordable(affordable: bool, missing_gold: int = 0) -> void:
	modulate = Color.WHITE if affordable else Color(1.0, 1.0, 1.0, 0.55)
	if card == null or _cost_label == null:
		return
	var cost: int = EconomyManager.get_card_cost(GameManager.local_player_id, card)
	_cost_label.text = "%d" % cost
	_cost_label.add_theme_color_override("font_color", CREAM if affordable else Color(1.0, 0.5, 0.45))
	_missing_label.visible = not affordable
	_missing_label.text = tr("(faltan %d)") % missing_gold


## Sacudida cuando la compra de esta carta fue rechazada.
func play_reject() -> void:
	var tween: Tween = create_tween()
	var base_x: float = position.x
	for offset: float in [-12.0, 12.0, -8.0, 8.0, 0.0]:
		tween.tween_property(self, "position:x", base_x + offset, 0.04)
	_style.border_color = Color(1.0, 0.25, 0.2)
	var flash: Tween = create_tween()
	flash.tween_interval(0.4)
	flash.tween_callback(func() -> void: _style.border_color = type_color(card.card_type) if card != null else Color.WHITE)


func _gui_input(event: InputEvent) -> void:
	if card == null:
		return
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			_pressed = true
			_press_position = button.global_position
			_animate_scale(Vector2(0.95, 0.95), 0.06, false)
		else:
			if _dragging:
				drag_released.emit(self, button.global_position)
			_pressed = false
			_dragging = false
			_animate_scale(Vector2.ONE, 0.22, true)
		accept_event()
	elif event is InputEventMouseMotion and _pressed:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if not _dragging and motion.global_position.distance_to(_press_position) > DRAG_THRESHOLD:
			_dragging = true
			drag_started.emit(self, motion.global_position)
		if _dragging:
			drag_moved.emit(self, motion.global_position)
		accept_event()


func _cancel_gesture() -> void:
	_pressed = false
	_dragging = false


## Hundir al pulsar y rebote al soltar (igual que los botones).
func _animate_scale(target: Vector2, duration: float, overshoot: bool) -> void:
	pivot_offset = size * 0.5
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	_press_tween = create_tween()
	var step: PropertyTweener = _press_tween.tween_property(self, "scale", target, duration)
	if overshoot:
		step.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		step.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Reduce la fuente hasta que el texto quepa en `max_width` (nombres largos).
func _fit_font(label: Label, start_size: int, min_size: int, max_width: float) -> void:
	var font: Font = label.get_theme_font("font")
	var font_size: int = start_size
	while font_size > min_size and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)


func _make_icon() -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.custom_minimum_size = Vector2(0.0, 96.0)
	return icon


func _make_label(font_size: int, parent: Control) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
