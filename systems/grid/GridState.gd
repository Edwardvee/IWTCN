class_name GridState
extends RefCounted
## Estado lógico del grid de un jugador: plots desbloqueados y contenido de
## los 24 slots. No contiene nodos; es lo que se serializa para red/snapshots.
##
## REGLA: solo GridManager llama a los métodos que modifican el estado.
## slot_index = plot_index × 4 + slot_local (0..3).

const PLOT_COUNT: int = GameRules.PLOT_COUNT
const SLOTS_PER_PLOT: int = GameRules.SLOTS_PER_PLOT
const SLOT_COUNT: int = PLOT_COUNT * SLOTS_PER_PLOT


class SlotState:
	extends RefCounted

	var structure_id: StringName = &""
	var building_id: int = 0
	## Oro pagado por la estructura (base para el reembolso al vender).
	var invested_gold: int = 0

	func is_empty() -> bool:
		return structure_id == &""

	func to_dict() -> Dictionary:
		return {
			"structure_id": structure_id,
			"building_id": building_id,
			"invested_gold": invested_gold,
		}


var _unlocked_plots: Array[bool] = []
var _slots: Array[SlotState] = []


func _init(initial_unlocked_plots: PackedInt32Array) -> void:
	_unlocked_plots.resize(PLOT_COUNT)
	_unlocked_plots.fill(false)
	for plot_index: int in initial_unlocked_plots:
		if is_valid_plot(plot_index):
			_unlocked_plots[plot_index] = true
	for _slot: int in SLOT_COUNT:
		_slots.append(SlotState.new())


static func is_valid_plot(plot_index: int) -> bool:
	return plot_index >= 0 and plot_index < PLOT_COUNT


static func is_valid_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < SLOT_COUNT


static func plot_of_slot(slot_index: int) -> int:
	if not is_valid_slot(slot_index):
		return -1
	@warning_ignore("integer_division")
	return slot_index / SLOTS_PER_PLOT


static func first_slot_of_plot(plot_index: int) -> int:
	return plot_index * SLOTS_PER_PLOT


func is_plot_unlocked(plot_index: int) -> bool:
	return is_valid_plot(plot_index) and _unlocked_plots[plot_index]


func is_slot_free(slot_index: int) -> bool:
	return is_valid_slot(slot_index) and _slots[slot_index].is_empty()


## Solo lectura por convención: no modificar el SlotState devuelto.
func get_slot(slot_index: int) -> SlotState:
	if not is_valid_slot(slot_index):
		return null
	return _slots[slot_index]


func count_structures(structure_id: StringName) -> int:
	var count: int = 0
	for slot_state: SlotState in _slots:
		if slot_state.structure_id == structure_id:
			count += 1
	return count


func find_first_free_slot_in_plot(plot_index: int) -> int:
	if not is_valid_plot(plot_index):
		return -1
	var first: int = first_slot_of_plot(plot_index)
	for slot_index: int in range(first, first + SLOTS_PER_PLOT):
		if _slots[slot_index].is_empty():
			return slot_index
	return -1


func get_occupied_slots() -> PackedInt32Array:
	var occupied: PackedInt32Array = PackedInt32Array()
	for slot_index: int in SLOT_COUNT:
		if not _slots[slot_index].is_empty():
			occupied.append(slot_index)
	return occupied


func unlock_plot(plot_index: int) -> void:
	if is_valid_plot(plot_index):
		_unlocked_plots[plot_index] = true


func place_structure(slot_index: int, structure_id: StringName, building_id: int, invested_gold: int) -> void:
	var slot_state: SlotState = get_slot(slot_index)
	if slot_state == null:
		return
	slot_state.structure_id = structure_id
	slot_state.building_id = building_id
	slot_state.invested_gold = invested_gold


func clear_slot(slot_index: int) -> void:
	var slot_state: SlotState = get_slot(slot_index)
	if slot_state == null:
		return
	slot_state.structure_id = &""
	slot_state.building_id = 0
	slot_state.invested_gold = 0


func to_dict() -> Dictionary:
	var slot_dicts: Array[Dictionary] = []
	for slot_state: SlotState in _slots:
		slot_dicts.append(slot_state.to_dict())
	return {
		"unlocked_plots": _unlocked_plots.duplicate(),
		"slots": slot_dicts,
	}
