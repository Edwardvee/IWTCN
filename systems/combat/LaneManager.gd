class_name LaneManager
extends Node2D
## Sistema del carril: aparición, registro, consultas de objetivo, resolución
## de golpes y retirada de unidades.
##
## Simulación determinista por tick (solo en la autoridad):
##   1. cada unidad viva simula en orden de unit_id (moverse, decidir golpes,
##      disparar proyectiles, decidir curas)
##   2. los proyectiles avanzan en orden de id; al llegar encolan su golpe
##   3. se aplican los golpes en cola (todos a la vez: dos unidades que se
##      golpean en el mismo tick se hacen daño ambas)
##   4. se aplican las curas en cola, solo a unidades que sigan vivas
##      (una cura nunca revive a quien murió en este mismo tick)
##   5. las muertas salen del registro (nadie más puede apuntarles) y quedan
##      en _dying hasta terminar su animación; después se liberan
##
## Fase 5: base mínima para el combate. La Fase 6 añade la interacción con
## los castillos al final del carril.

class PendingHit:
	extends RefCounted

	var attacker_id: int = 0
	var target_id: int = 0
	var amount: float = 0.0

	func _init(p_attacker_id: int, p_target_id: int, p_amount: float) -> void:
		attacker_id = p_attacker_id
		target_id = p_target_id
		amount = p_amount


class PendingHeal:
	extends RefCounted

	var healer_id: int = 0
	var target_id: int = 0
	var amount: float = 0.0

	func _init(p_healer_id: int, p_target_id: int, p_amount: float) -> void:
		healer_id = p_healer_id
		target_id = p_target_id
		amount = p_amount


## Separación horizontal entre unidades que aparecen juntas.
const SPAWN_SPACING_X: float = 60.0

@export var lane_top_y: float = 900.0
@export var lane_bottom_y: float = 2300.0
@export var lane_center_x: float = 540.0
## Distancia desde el extremo propio del carril donde aparecen las unidades
## (si no hay Marker2D de spawn asignado).
@export var spawn_margin: float = 20.0
@export var player_spawn: Marker2D
@export var enemy_spawn: Marker2D
@export var player_units_container: Node2D
@export var enemy_units_container: Node2D
@export var projectiles_container: Node2D

## Unidades vivas, ordenadas por unit_id.
var _units: Array[UnitBase] = []
var _units_by_id: Dictionary[int, UnitBase] = {}
var _dying: Array[UnitBase] = []
## Proyectiles en vuelo, ordenados por projectile_id.
var _projectiles: Array[Projectile] = []
var _pending_hits: Array[PendingHit] = []
var _pending_heals: Array[PendingHeal] = []


func _ready() -> void:
	EventBus.partida_iniciada.connect(_on_partida_iniciada)


func _physics_process(delta: float) -> void:
	simulate_step(delta)


func simulate_step(delta: float) -> void:
	if delta <= 0.0 or not GameManager.is_authority() or not GameManager.is_match_running():
		return
	for unit: UnitBase in _units:
		unit.simulate(delta)
	_simulate_projectiles(delta)
	_resolve_hits()
	_resolve_heals()
	_process_deaths()
	_update_dying(delta)


# --- Aparición -------------------------------------------------------------

func spawn_unit(unit_data: UnitData, team: int, world_position: Vector2) -> UnitBase:
	if unit_data == null or not MatchTypes.is_valid_player_id(team) or GameManager.match_state == null:
		push_error("LaneManager.spawn_unit: parámetros inválidos")
		return null
	var unit: UnitBase = UnitBase.new()
	unit.setup(GameManager.match_state.allocate_entity_id(), team, unit_data, self)
	_get_container(team).add_child(unit)
	unit.global_position = world_position
	_register(unit)
	EventBus.unidad_desplegada.emit(unit, team)
	return unit


## Hace aparecer `count` unidades en el punto de spawn del equipo, en fila.
func spawn_group(unit_data: UnitData, team: int, count: int) -> Array[UnitBase]:
	var spawned: Array[UnitBase] = []
	for index: int in count:
		var unit: UnitBase = spawn_unit(unit_data, team, get_spawn_position(team, index, count))
		if unit != null:
			spawned.append(unit)
	return spawned


func get_spawn_position(team: int, index: int, count: int) -> Vector2:
	var base: Vector2
	var marker: Marker2D = player_spawn if team == MatchTypes.PLAYER_BOTTOM else enemy_spawn
	if marker != null:
		base = marker.global_position
	elif team == MatchTypes.PLAYER_BOTTOM:
		base = Vector2(lane_center_x, lane_bottom_y - spawn_margin)
	else:
		base = Vector2(lane_center_x, lane_top_y + spawn_margin)
	var offset_x: float = (float(index) - float(count - 1) * 0.5) * SPAWN_SPACING_X
	return base + Vector2(offset_x, 0.0)


## Y donde se detienen las unidades del equipo (extremo rival del carril).
func get_lane_end_y(team: int) -> float:
	return lane_top_y if team == MatchTypes.PLAYER_BOTTOM else lane_bottom_y


# --- Consultas ---------------------------------------------------------------

func get_unit(unit_id: int) -> UnitBase:
	return _units_by_id.get(unit_id, null)


func get_alive_units() -> Array[UnitBase]:
	return _units.duplicate()


func get_alive_count(team: int) -> int:
	var count: int = 0
	for unit: UnitBase in _units:
		if unit.team == team:
			count += 1
	return count


## Enemigo vivo más cercano (distancia de borde a borde) dentro de max_range.
## Desempate determinista: menor unit_id.
func find_nearest_enemy_in_range(seeker: UnitBase, max_range: float) -> UnitBase:
	var best: UnitBase = null
	var best_distance: float = INF
	for candidate: UnitBase in _units:
		if candidate.team == seeker.team or candidate.is_dead:
			continue
		var distance: float = seeker.edge_distance_to(candidate)
		if distance > max_range:
			continue
		if distance < best_distance or (is_equal_approx(distance, best_distance) and candidate.unit_id < best.unit_id):
			best = candidate
			best_distance = distance
	return best


## Aliado vivo y herido con menor % de vida dentro de max_range (sin contar
## al propio buscador). Desempate determinista: menor unit_id.
func find_lowest_hp_ally_in_range(seeker: UnitBase, max_range: float) -> UnitBase:
	var best: UnitBase = null
	var best_ratio: float = INF
	for candidate: UnitBase in _units:
		if candidate == seeker or candidate.team != seeker.team or not candidate.is_injured():
			continue
		if seeker.edge_distance_to(candidate) > max_range:
			continue
		var ratio: float = candidate.get_hp_ratio()
		if ratio < best_ratio or (is_equal_approx(ratio, best_ratio) and candidate.unit_id < best.unit_id):
			best = candidate
			best_ratio = ratio
	return best


func get_projectile_count() -> int:
	return _projectiles.size()


# --- Combate -----------------------------------------------------------------

func queue_hit(attacker: UnitBase, target: UnitBase, amount: float) -> void:
	if attacker == null or target == null or attacker.is_dead:
		return
	_pending_hits.append(PendingHit.new(attacker.unit_id, target.unit_id, amount))


func queue_heal(healer: UnitBase, target: UnitBase, amount: float) -> void:
	if healer == null or target == null or healer.is_dead:
		return
	_pending_heals.append(PendingHeal.new(healer.unit_id, target.unit_id, amount))


## Dispara un proyectil teledirigido. source_id es el id lógico de quien
## dispara (unidad o, en la Fase 8, torre).
func spawn_projectile(source_id: int, team: int, origin: Vector2, target_id: int, amount: float, speed: float) -> Projectile:
	if GameManager.match_state == null or get_unit(target_id) == null:
		return null
	var projectile: Projectile = Projectile.new()
	projectile.setup(GameManager.match_state.allocate_entity_id(), source_id, team, target_id, amount, speed)
	var container: Node = projectiles_container if projectiles_container != null else self
	container.add_child(projectile)
	projectile.global_position = origin
	_projectiles.append(projectile)
	return projectile


func _simulate_projectiles(delta: float) -> void:
	var index: int = 0
	while index < _projectiles.size():
		var projectile: Projectile = _projectiles[index]
		var target: UnitBase = get_unit(projectile.target_id)
		if target == null or target.is_dead:
			# El objetivo murió antes de la llegada: el proyectil se pierde.
			_projectiles.remove_at(index)
			projectile.queue_free()
			continue
		if projectile.simulate_towards(target.global_position, delta):
			_pending_hits.append(PendingHit.new(projectile.source_id, projectile.target_id, projectile.damage))
			_projectiles.remove_at(index)
			projectile.queue_free()
			continue
		index += 1


func _resolve_hits() -> void:
	for hit: PendingHit in _pending_hits:
		var target: UnitBase = get_unit(hit.target_id)
		if target != null and not target.is_dead:
			target.receive_damage(hit.amount, hit.attacker_id)
	_pending_hits.clear()


func _resolve_heals() -> void:
	for heal: PendingHeal in _pending_heals:
		var target: UnitBase = get_unit(heal.target_id)
		if target != null and not target.is_dead:
			target.receive_heal(heal.amount, heal.healer_id)
	_pending_heals.clear()


func _process_deaths() -> void:
	var index: int = 0
	while index < _units.size():
		var unit: UnitBase = _units[index]
		if not unit.is_dead:
			index += 1
			continue
		_units.remove_at(index)
		_units_by_id.erase(unit.unit_id)
		_dying.append(unit)
		EventBus.unidad_eliminada.emit(unit, unit.team)


func _update_dying(delta: float) -> void:
	var index: int = 0
	while index < _dying.size():
		var unit: UnitBase = _dying[index]
		unit.simulate(delta)
		if unit.is_ready_to_free():
			_dying.remove_at(index)
			unit.queue_free()
		else:
			index += 1


# --- Registro ----------------------------------------------------------------

func _register(unit: UnitBase) -> void:
	# Los ids se asignan crecientes, así que añadir al final mantiene el orden.
	_units.append(unit)
	_units_by_id[unit.unit_id] = unit


func _get_container(team: int) -> Node:
	var container: Node2D = player_units_container if team == MatchTypes.PLAYER_BOTTOM else enemy_units_container
	return container if container != null else self


func clear_units() -> void:
	for unit: UnitBase in _units:
		unit.queue_free()
	for unit: UnitBase in _dying:
		unit.queue_free()
	for projectile: Projectile in _projectiles:
		projectile.queue_free()
	_units.clear()
	_units_by_id.clear()
	_dying.clear()
	_projectiles.clear()
	_pending_hits.clear()
	_pending_heals.clear()


func to_dict() -> Dictionary:
	var unit_dicts: Array[Dictionary] = []
	for unit: UnitBase in _units:
		unit_dicts.append(unit.to_dict())
	var projectile_dicts: Array[Dictionary] = []
	for projectile: Projectile in _projectiles:
		projectile_dicts.append({
			"projectile_id": projectile.projectile_id,
			"source_id": projectile.source_id,
			"target_id": projectile.target_id,
			"position": projectile.global_position,
		})
	return {"units": unit_dicts, "projectiles": projectile_dicts}


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	clear_units()
