class_name UnitStatModifiers
extends RefCounted
## Modificadores de estadísticas que recibe una unidad al aparecer.
## Punto único de cálculo: hoy los bonus de cuartel; en la Fase 10, los
## buffs globales. Se calcula solo a partir del estado de partida
## (PlayerState + GameDatabase), así que es determinista y sincronizable.

var bonus_max_hp: float = 0.0
var bonus_damage: float = 0.0


## Modificadores para una unidad `unit_data` del jugador `player_id`.
## Cuartel: por cada estructura adicional (a partir de la 2.ª) que produce
## esta unidad, suma sus unit_bonus_* (p. ej. +1 daño y +10 vida).
static func for_player(player_id: int, unit_data: UnitData) -> UnitStatModifiers:
	var modifiers: UnitStatModifiers = UnitStatModifiers.new()
	var player_state: PlayerState = GameManager.get_player_state(player_id)
	if player_state == null or GameManager.database == null or unit_data == null:
		return modifiers
	for structure: StructureData in GameManager.database.structures:
		if structure.kind != StructureData.Kind.SPAWNER or structure.spawn_unit != unit_data:
			continue
		var extra_buildings: int = maxi(0, player_state.grid.count_structures(structure.id) - 1)
		modifiers.bonus_max_hp += structure.unit_bonus_hp_per_extra_building * extra_buildings
		modifiers.bonus_damage += structure.unit_bonus_damage_per_extra_building * extra_buildings
	return modifiers
