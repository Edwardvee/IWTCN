class_name BuildingSlot
extends Node2D
## Nodo visual de un slot. Refleja GridState; no decide reglas.
## El origen del nodo es la esquina superior izquierda del slot.

const SELECTED_COLOR: Color = Color(1.0, 0.85, 0.2)

var slot_index: int = -1
var owner_id: int = MatchTypes.NO_PLAYER
var size: Vector2 = Vector2.ZERO
var structure: StructureBase = null

var _selected: bool = false


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


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.3))
	draw_rect(rect, Color(1.0, 1.0, 1.0, 0.25), false, 2.0)
	if _selected:
		draw_rect(rect, SELECTED_COLOR, false, 6.0)
