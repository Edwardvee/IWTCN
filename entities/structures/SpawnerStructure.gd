class_name SpawnerStructure
extends StructureBase
## Barracks / Church: cada spawn_interval_per_level[nivel] segundos hace
## aparecer spawn_count_per_level[nivel] unidades de spawn_unit en el punto
## de spawn del dueño. Los bonus por cuartel adicional los aplica
## UnitStatModifiers al crear la unidad.


## Intervalo del nivel con los buffs de producción del dueño aplicados.
func get_production_interval() -> float:
	var race: RaceData = GameManager.get_race(owner_id)
	var race_multiplier: float = race.production_interval_multiplier if race != null else 1.0
	return BuffSystem.get_production_interval(owner_id, data.get_spawn_interval(level) * race_multiplier)


func _on_production_cycle() -> void:
	var lane: LaneManager = get_lane()
	if lane == null or data.spawn_unit == null:
		return
	lane.spawn_group(data.spawn_unit, owner_id, data.get_spawn_count(level))
	play_bounce()


func _on_visual_cycle() -> void:
	play_bounce()
