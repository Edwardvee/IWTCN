class_name Plot
extends Node2D
## Nodo visual de un plot (2×2 slots). Muestra fondo de equipo y, si está
## bloqueado, una capa oscura con el coste de desbloqueo.
## El origen del nodo es la esquina superior izquierda del plot.

const COIN_COLOR: Color = Color(0.98, 0.82, 0.25)

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
	# Con la vista girada, moneda y número se reflejan para leerse "● 40".
	var flipped: bool = ViewOrientation.is_flipped()
	_cost_label.position.x = size.x * 0.5 + 10.0 - _cost_label.size.x if flipped else size.x * 0.5 - 10.0
	ViewOrientation.orient(_cost_label)
	_overlay.queue_redraw()


func _create_overlay() -> void:
	# z_index 1 la dibuja sobre los slots y estructuras (que están en z 0).
	_overlay = Node2D.new()
	_overlay.name = "LockOverlay"
	_overlay.z_index = 1
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_cost_label = Label.new()
	_cost_label.position = Vector2(size.x * 0.5 - 10.0, size.y * 0.5 - 40.0)
	_cost_label.size = Vector2(size.x * 0.5, 80.0)
	_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cost_label.add_theme_font_size_override("font_size", 52)
	_cost_label.add_theme_constant_override("outline_size", 8)
	_cost_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_overlay.add_child(_cost_label)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(rect, MatchTypes.team_color(owner_id).darkened(0.65))
	draw_rect(rect, MatchTypes.team_color(owner_id).darkened(0.3), false, 3.0)


func _draw_overlay() -> void:
	_overlay.draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.6))
	var coin_offset: float = 45.0 if ViewOrientation.is_flipped() else -45.0
	_overlay.draw_circle(Vector2(size.x * 0.5 + coin_offset, size.y * 0.5), 28.0, COIN_COLOR)
