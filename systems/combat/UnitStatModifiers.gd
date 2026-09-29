class_name UnitStatModifiers
extends RefCounted
## Modificadores de estadísticas de una unidad. Se calculan solo a partir del
## estado de partida (PlayerState + GameDatabase): deterministas y sincronizables.
##   from_barracks: bonus de cuartel, se fija al aparecer la unidad.
##   from_buffs:    buffs globales, se recalculan en vivo al comprar un buff.
## Estadística final = (base + bonus) × multiplicador; mitigación = base + bonus.

var bonus_max_hp: float = 0.0
var bonus_damage: float = 0.0
var bonus_move_speed: float = 0.0
var bonus_mitigation: float = 0.0
var max_hp_multiplier: float = 1.0
var damage_multiplier: float = 1.0
## Ritmo de ataque respecto al base (2.0 = ataca el doble de rápido). Solo lo fija el
## cuartel al aparecer la unidad.
var attack_speed_multiplier: float = 1.0
var move_speed_multiplier: float = 1.0


## Cuartel: por cada estructura adicional (a partir de la 2.ª) que produce
## esta unidad, suma sus unit_bonus_* (p. ej. +1 daño y +10 vida).
static func from_barracks(player_id: int, unit_data: UnitData) -> UnitStatModifiers:
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
		modifiers.attack_speed_multiplier = structure.get_unit_attack_speed(player_state.grid.count_structures(structure.id))
	return modifiers


static func from_buffs(player_id: int, unit_data: UnitData) -> UnitStatModifiers:
	var modifiers: UnitStatModifiers = UnitStatModifiers.new()
	if unit_data == null:
		return modifiers
	for buff: BuffData in BuffSystem.get_buffs(player_id):
		if not buff.affects_unit(unit_data.id):
			continue
		var is_percent: bool = buff.operation == BuffData.Operation.PERCENT
		match buff.stat:
			BuffData.Stat.MOVE_SPEED:
				if is_percent:
					modifiers.move_speed_multiplier += buff.value
				else:
					modifiers.bonus_move_speed += buff.value
			BuffData.Stat.MAX_HP:
				if is_percent:
					modifiers.max_hp_multiplier += buff.value
				else:
					modifiers.bonus_max_hp += buff.value
			BuffData.Stat.DAMAGE:
				if is_percent:
					modifiers.damage_multiplier += buff.value
				else:
					modifiers.bonus_damage += buff.value
			BuffData.Stat.DAMAGE_MITIGATION:
				# "+10 % armadura" = +0.10 de mitigación en ambos modos.
				modifiers.bonus_mitigation += buff.value
	return modifiers


func combined_with(other: UnitStatModifiers) -> UnitStatModifiers:
	var result: UnitStatModifiers = UnitStatModifiers.new()
	result.bonus_max_hp = bonus_max_hp + other.bonus_max_hp
	result.bonus_damage = bonus_damage + other.bonus_damage
	result.bonus_move_speed = bonus_move_speed + other.bonus_move_speed
	result.bonus_mitigation = bonus_mitigation + other.bonus_mitigation
	result.max_hp_multiplier = max_hp_multiplier + other.max_hp_multiplier - 1.0
	result.damage_multiplier = damage_multiplier + other.damage_multiplier - 1.0
	result.attack_speed_multiplier = attack_speed_multiplier * other.attack_speed_multiplier
	result.move_speed_multiplier = move_speed_multiplier + other.move_speed_multiplier - 1.0
	return result
