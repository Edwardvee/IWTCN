class_name SpawnerStructure
extends StructureBase
## Barracks / Church: cada spawn_interval_per_level[nivel] segundos hace
## aparecer spawn_count_per_level[nivel] unidades de spawn_unit en el punto
## de spawn del dueño. Los bonus por cuartel adicional los aplica
## UnitStatModifiers al crear la unidad.


func get_production_interval() -> float:
	return data.get_spawn_interval(level)


func _on_production_cycle() -> void:
	var lane: LaneManager = get_lane()
	if lane == null or data.spawn_unit == null:
		return
	lane.spawn_group(data.spawn_unit, owner_id, data.get_spawn_count(level))
