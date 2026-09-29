class_name TowerStructure
extends StructureBase
## Tower: dispara proyectiles al enemigo más cercano en rango.
## Está fuera del carril: el rango se mide en el eje del carril (Y) desde la
## torre hasta el borde de la unidad, igual que el resto del combate 1D.
## Por eso la posición importa: la fila delantera cubre más carril.

var cooldown_left: float = 0.0


func simulate(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - delta)
	if cooldown_left > 0.0:
		return
	var lane: LaneManager = get_lane()
	if lane == null:
		return
	var target: UnitBase = lane.find_nearest_enemy_to_y(owner_id, global_position.y, data.get_tower_range(level))
	if target == null:
		return
	lane.spawn_projectile(building_id, owner_id, global_position, target.unit_id, data.get_tower_damage(level), data.tower_projectile_speed)
	cooldown_left = data.get_tower_cooldown(level) / BuffSystem.get_tower_fire_rate_multiplier(owner_id)


func to_dict() -> Dictionary:
	var result: Dictionary = super()
	result["cooldown_left"] = cooldown_left
	return result


func _draw() -> void:
	super()
	# Indicador de rango: marca del alcance hacia el carril.
	var reach: float = data.get_tower_range(level)
	var toward_lane: float = -1.0 if owner_id == MatchTypes.PLAYER_BOTTOM else 1.0
	var tip: Vector2 = Vector2(0.0, toward_lane * reach)
	draw_dashed_line(Vector2(0.0, toward_lane * body_size.y * 0.5), tip, Color(1.0, 1.0, 1.0, 0.25), 3.0, 14.0)
	draw_line(tip + Vector2(-30.0, 0.0), tip + Vector2(30.0, 0.0), Color(1.0, 1.0, 1.0, 0.35), 3.0)
