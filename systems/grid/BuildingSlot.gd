class_name BuildingSlot
extends Node2D
## Nodo visual de un slot. Refleja GridState; no decide reglas.
## El origen del nodo es la esquina superior izquierda del slot.

const SELECTED_COLOR: Color = Color(1.0, 0.85, 0.2)

var slot_index: int = -1
var owner_id: int = MatchTypes.NO_PLAYER
var size: Vector2 = Vector2.ZERO
var structure: StructureBase = null

## Ayuda visual mientras se arrastra una estructura.
enum Hint { NONE, VALID, INVALID }
const HINT_VALID_FILL: Color = Color(0.3, 1.0, 0.4, 0.22)
const HINT_INVALID_BORDER: Color = Color(1.0, 0.3, 0.25)
const HINT_VALID_BORDER: Color = Color(0.4, 1.0, 0.5)
const PAD_COLOR: Color = Color(0.0, 0.0, 0.0, 0.22)
const BRACKET_COLOR: Color = Color(1.0, 0.95, 0.8, 0.32)
const BRACKET_LENGTH: float = 20.0

static var _border_style: StyleBoxFlat = null

var _selected: bool = false
var _hint: Hint = Hint.NONE


func setup(p_slot_index: int, p_owner_id: int, p_size: Vector2) -> void:
	slot_index = p_slot_index
	owner_id = p_owner_id
	size = p_size
	name = "Slot_%d" % slot_index
	queue_redraw()


func is_occupied() -> bool:
	return structure != null


func attach_structure(new_structure: StructureBase) -> void:
	structure = new_structure
	add_child(new_structure)
	new_structure.position = size * 0.5


func detach_structure() -> StructureBase:
	var detached: StructureBase = structure
	structure = null
	if detached != null and detached.get_parent() == self:
		remove_child(detached)
	return detached


func set_selected(selected: bool) -> void:
	if _selected == selected:
		return
	_selected = selected
	queue_redraw()


func get_hint() -> Hint:
	return _hint


func set_hint(hint: Hint) -> void:
	if _hint == hint:
		return
	_hint = hint
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(rect, PAD_COLOR)
	_draw_brackets(rect.grow(-4.0))
	if _hint == Hint.VALID:
		draw_rect(rect, HINT_VALID_FILL)
		_draw_border(rect, HINT_VALID_BORDER, 3)
	if _selected:
		var border: Color = SELECTED_COLOR
		if _hint == Hint.VALID:
			border = HINT_VALID_BORDER
		elif _hint == Hint.INVALID:
			border = HINT_INVALID_BORDER
		_draw_border(rect, border, 6)


## Esquinas de "aquí se construye" en lugar de un recuadro completo.
func _draw_brackets(rect: Rect2) -> void:
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var dx: float = BRACKET_LENGTH if corner.x <= rect.position.x else -BRACKET_LENGTH
		var dy: float = BRACKET_LENGTH if corner.y <= rect.position.y else -BRACKET_LENGTH
		draw_polyline(PackedVector2Array([corner + Vector2(dx, 0.0), corner, corner + Vector2(0.0, dy)]), BRACKET_COLOR, 3.0)


func _draw_border(rect: Rect2, color: Color, width: int) -> void:
	if _border_style == null:
		_border_style = StyleBoxFlat.new()
		_border_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		_border_style.set_corner_radius_all(10)
	_border_style.set_border_width_all(width)
	_border_style.border_color = color
	draw_style_box(_border_style, rect)
