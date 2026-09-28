class_name CardView
extends PanelContainer
## Vista de una carta de la tienda. Solo presentación y gesto de arrastre:
## emite señales y ShopPanel decide qué hacer. Nunca ejecuta gameplay.
##
## Usa eventos de ratón: en móvil llegan emulados desde el táctil
## (emulate_mouse_from_touch), así hay un único camino para ambos.
## Mientras el botón sigue pulsado, Godot envía el movimiento a este control
## aunque el puntero salga de su rectángulo.

signal drag_started(view: CardView, screen_position: Vector2)
signal drag_moved(view: CardView, screen_position: Vector2)
signal drag_released(view: CardView, screen_position: Vector2)

const DRAG_THRESHOLD: float = 12.0
const TYPE_NAMES: Dictionary[int, String] = {
	CardData.CardType.STRUCTURE: "ESTRUCTURA",
	CardData.CardType.DIRECT_UNIT: "UNIDADES",
	CardData.CardType.GLOBAL_BUFF: "MEJORA",
}

var offer_index: int = -1
var card: CardData = null

var _type_label: Label = null
var _name_label: Label = null
var _description_label: Label = null
var _cost_label: Label = null
var _style: StyleBoxFlat = null
var _pressed: bool = false
var _dragging: bool = false
var _press_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(320.0, 250.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style = StyleBoxFlat.new()
	_style.set_corner_radius_all(18)
	_style.set_border_width_all(4)
	_style.set_content_margin_all(14.0)
	add_theme_stylebox_override("panel", _style)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layout)
	_type_label = _make_label(22, layout)
	_name_label = _make_label(34, layout)
	_description_label = _make_label(22, layout)
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cost_label = _make_label(38, layout)
	set_card(-1, null)


func set_card(p_offer_index: int, p_card: CardData) -> void:
	offer_index = p_offer_index
	card = p_card
	_cancel_gesture()
	visible = card != null
	if card == null:
		return
	_type_label.text = TYPE_NAMES.get(card.card_type, "")
	_name_label.text = card.display_name
	_description_label.text = card.description
	refresh_cost()
	_style.bg_color = card.color.darkened(0.55)
	_style.border_color = card.color


## Precio real para el jugador local (sube con cada copia construida).
func refresh_cost() -> void:
	if card != null:
		_cost_label.text = "● %d" % EconomyManager.get_card_cost(GameManager.local_player_id, card)


func set_affordable(affordable: bool) -> void:
	modulate = Color.WHITE if affordable else Color(1.0, 1.0, 1.0, 0.5)


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
		else:
			if _dragging:
				drag_released.emit(self, button.global_position)
			_pressed = false
			_dragging = false
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


func _make_label(font_size: int, parent: Control) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	parent.add_child(label)
	return label
