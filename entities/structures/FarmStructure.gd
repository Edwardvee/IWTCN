class_name FarmStructure
extends StructureBase
## Farm: genera oro cada income_interval a través de EconomyManager.
##
## Con income_shared_between_buildings = true, income_per_level[nivel] es el
## ingreso total de todas las granjas del jugador: cada una aporta
## total / nº de granjas y el resto de la división lo aporta la granja con
## menor building_id (así el total es exacto y determinista).


func get_production_interval() -> float:
	return data.income_interval


func get_income_per_cycle() -> int:
	var total: int = data.get_income(level)
	if not data.income_shared_between_buildings or grid == null:
		return total
	var farm_count: int = maxi(1, grid.get_state().count_structures(data.id))
	@warning_ignore("integer_division")
	var share: int = total / farm_count
	if grid.get_first_building_id(data.id) == building_id:
		share += total % farm_count
	return share


func _on_production_cycle() -> void:
	EconomyManager.add_gold(owner_id, get_income_per_cycle())
