class_name Plot
extends Node2D
## Nodo visual de un plot (2×2 slots). Muestra fondo de equipo y, si está
## bloqueado, una capa oscura con el coste de desbloqueo.
## El origen del nodo es la esquina superior izquierda del plot.

const FLOOR: Texture2D = preload("res://assets/world/plot_floor.svg")
const COIN: Texture2D = preload("res://assets/ui/coin.svg")
const PADLOCK: Texture2D = preload("res://assets/ui/padlock.svg")
const OUTLINE_COLOR: Color = Color(0.09, 0.07, 0.12)
const FRAME_WIDTH: int = 6
const COST_FONT_SIZE: int = 46

static var _outline_style: StyleBoxFlat = null
static var _team_styles: Dictionary[int, StyleBoxFlat] = {}

var plot_index: int = -1
var owner_id: int = MatchTypes.NO_PLAYER
var size: Vector2 = Vector2.ZERO
var locked: bool = true
var unlock_cost: int = 0

var _overlay: Node2D = null
var _cost_label: Label = null


func setup(p_plot_index: int, p_owner_id: int, p_size: Vector2) -> void:
	plot_index = p_plot_index
	owner_id = p_owner_id
	size = p_size
	name = "Plot_%d" % plot_index
	_create_overlay()
	queue_redraw()


func set_lock_state(is_locked: bool, cost: int) -> void:
	locked = is_locked
	unlock_cost = cost
	_overlay.visible = locked
	_cost_label.text = str(unlock_cost)
	_layout_cost_label()
	_overlay.queue_redraw()


## Fila "moneda + precio" bajo el candado. Con la vista girada 180° todo el
## contenido se refleja alrededor del centro para leerse igual desde abajo.
func _layout_cost_label() -> void:
	var label_position: Vector2 = Vector2(size.x * 0.5 - 4.0, size.y * 0.5 + 12.0)
	var flipped: bool = ViewOrientation.is_flipped()
	_cost_label.size = Vector2(size.x * 0.5, 64.0)
	_cost_label.position = size - label_position - _cost_label.size if flipped else label_position
	ViewOrientation.orient(_cost_label)


func _create_overlay() -> void:
	# z_index 1 la dibuja sobre los slots y estructuras (que están en z 0).
	_overlay = Node2D.new()
	_overlay.name = "LockOverlay"
	_overlay.z_index = 1
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_cost_label = Label.new()
	_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cost_label.add_theme_font_size_override("font_size", COST_FONT_SIZE)
	_cost_label.add_theme_constant_override("outline_size", 10)
	_cost_label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	_overlay.add_child(_cost_label)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var team: Color = MatchTypes.team_color(owner_id)
	draw_texture_rect(FLOOR, rect.grow(-3.0), false)
	draw_rect(rect.grow(-3.0), Color(team, 0.1))
	draw_style_box(_get_outline_style(), rect.grow(3.0))
	draw_style_box(_get_team_style(owner_id), rect)


func _draw_overlay() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	_overlay.draw_rect(rect, Color(0.04, 0.03, 0.06, 0.5))
	if ViewOrientation.is_flipped():
		_overlay.draw_set_transform(size, PI, Vector2.ONE)
	else:
		_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var center: Vector2 = size * 0.5
	var lock_size: Vector2 = Vector2(92.0, 92.0)
	_overlay.draw_texture_rect(PADLOCK, Rect2(center + Vector2(-lock_size.x * 0.5, -lock_size.y - 4.0), lock_size), false)
	var coin_size: Vector2 = Vector2(52.0, 52.0)
	_overlay.draw_texture_rect(COIN, Rect2(center + Vector2(-coin_size.x - 26.0, 18.0), coin_size), false)
	_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _get_outline_style() -> StyleBoxFlat:
	if _outline_style == null:
		_outline_style = StyleBoxFlat.new()
		_outline_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		_outline_style.border_color = OUTLINE_COLOR
		_outline_style.set_border_width_all(4)
		_outline_style.set_corner_radius_all(16)
	return _outline_style


static func _get_team_style(team: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = _team_styles.get(team)
	if style == null:
		style = StyleBoxFlat.new()
		style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		style.border_color = MatchTypes.team_color(team).darkened(0.1)
		style.set_border_width_all(FRAME_WIDTH)
		style.set_corner_radius_all(12)
		_team_styles[team] = style
	return style
