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
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.3))
	draw_rect(rect, Color(1.0, 1.0, 1.0, 0.25), false, 2.0)
	if _hint == Hint.VALID:
		draw_rect(rect, HINT_VALID_FILL)
		draw_rect(rect, HINT_VALID_BORDER, false, 3.0)
	if _selected:
		var border: Color = SELECTED_COLOR
		if _hint == Hint.VALID:
			border = HINT_VALID_BORDER
		elif _hint == Hint.INVALID:
			border = HINT_INVALID_BORDER
		draw_rect(rect, border, false, 6.0)
