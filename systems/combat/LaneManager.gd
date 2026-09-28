class_name LaneManager
extends Node2D
## Sistema del carril: aparición, registro, consultas de objetivo, resolución
## de golpes/curas, interacción con los castillos y retirada de unidades.
##
## Simulación determinista por tick (solo en la autoridad):
##   1. cada unidad viva simula en orden de unit_id (moverse, decidir golpes,
##      disparar proyectiles, decidir curas)
##   2. los proyectiles avanzan en orden de id; al llegar encolan su golpe
##   3. se aplican los golpes en cola a unidades y castillos (todos a la vez:
##      dos unidades que se golpean en el mismo tick se hacen daño ambas)
##   4. se aplican las curas en cola, solo a unidades que sigan vivas
##      (una cura nunca revive a quien murió en este mismo tick)
##   5. las muertas salen del registro (nadie más puede apuntarles) y quedan
##      en _dying hasta terminar su animación; después se liberan
##
## Castillos: su vida vive en PlayerState.castle_hp (solo este sistema la
## modifica). Su frente está a `castle_front_offset` del extremo del carril.
## Los nodos Castle de la escena son solo visuales.

class PendingHit:
	extends RefCounted

	var attacker_id: int = 0
	var target_id: int = 0
	## Si es un jugador válido, el golpe va a su castillo (target_id se ignora).
	var castle_owner: int = MatchTypes.NO_PLAYER
	var amount: float = 0.0

	func _init(p_attacker_id: int, p_target_id: int, p_amount: float, p_castle_owner: int = MatchTypes.NO_PLAYER) -> void:
		attacker_id = p_attacker_id
		target_id = p_target_id
		amount = p_amount
		castle_owner = p_castle_owner


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
## Separación entre filas cuando un grupo supera SPAWN_ROW_SIZE unidades.
const SPAWN_SPACING_Y: float = 56.0
const SPAWN_ROW_SIZE: int = 4
## Desplazamiento lateral que alterna entre grupos consecutivos para que
## dos grupos seguidos no queden exactamente superpuestos.
const GROUP_STAGGER_X: float = 20.0

@export var lane_top_y: float = 900.0
@export var lane_bottom_y: float = 2300.0
@export var lane_center_x: float = 540.0
@export var lane_half_width: float = 150.0
## Distancia desde el extremo del carril hasta el frente del castillo.
@export var castle_front_offset: float = 20.0
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
## Conversiones decididas este tick: [id del convertidor, id del objetivo].
var _pending_conversions: Array[Vector2i] = []
## Nº de grupos aparecidos por equipo (para el escalonado lateral).
var _group_counter: Array[int] = [0, 0]


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
	_resolve_conversions()
	_process_deaths()
	_update_dying(delta)
	_check_castles()


# --- Aparición -------------------------------------------------------------

func spawn_unit(unit_data: UnitData, team: int, world_position: Vector2) -> UnitBase:
	if unit_data == null or not MatchTypes.is_valid_player_id(team) or GameManager.match_state == null:
		push_error("LaneManager.spawn_unit: parámetros inválidos")
		return null
	var unit: UnitBase = UnitBase.new()
	unit.setup(GameManager.match_state.allocate_entity_id(), team, unit_data, self, UnitStatModifiers.from_barracks(team, unit_data))
	_get_container(team).add_child(unit)
	unit.global_position = world_position
	_register(unit)
	EventBus.unidad_desplegada.emit(unit, team)
	return unit


## Grupo en el punto de spawn del equipo (producción de estructuras, debug).
func spawn_group(unit_data: UnitData, team: int, count: int) -> Array[UnitBase]:
	return spawn_group_at(unit_data, team, count, get_spawn_origin(team))


## Grupo centrado en `origin` (cartas de unidad: se sueltan en la zona propia).
## Filas de hasta SPAWN_ROW_SIZE; las siguientes filas quedan detrás.
func spawn_group_at(unit_data: UnitData, team: int, count: int, origin: Vector2) -> Array[UnitBase]:
	var spawned: Array[UnitBase] = []
	if not MatchTypes.is_valid_player_id(team):
		return spawned
	var stagger: float = float(_group_counter[team] % 3 - 1) * GROUP_STAGGER_X
	_group_counter[team] += 1
	var backward: Vector2 = -MatchTypes.forward_direction(team)
	for index: int in count:
		@warning_ignore("integer_division")
		var row: int = index / SPAWN_ROW_SIZE
		var row_count: int = mini(SPAWN_ROW_SIZE, count - row * SPAWN_ROW_SIZE)
		var column: int = index % SPAWN_ROW_SIZE
		var offset_x: float = (float(column) - float(row_count - 1) * 0.5) * SPAWN_SPACING_X + stagger
		var spawn_position: Vector2 = origin + Vector2(offset_x, 0.0) + backward * (row * SPAWN_SPACING_Y)
		spawn_position.x = clampf(spawn_position.x, lane_center_x - lane_half_width, lane_center_x + lane_half_width)
		var unit: UnitBase = spawn_unit(unit_data, team, spawn_position)
		if unit != null:
			spawned.append(unit)
	return spawned


func get_spawn_origin(team: int) -> Vector2:
	var marker: Marker2D = player_spawn if team == MatchTypes.PLAYER_BOTTOM else enemy_spawn
	if marker != null:
		return marker.global_position
	if team == MatchTypes.PLAYER_BOTTOM:
		return Vector2(lane_center_x, lane_bottom_y - spawn_margin)
	return Vector2(lane_center_x, lane_top_y + spawn_margin)


## Mitad propia del carril, donde un jugador puede soltar cartas de unidad.
func get_deploy_rect(team: int) -> Rect2:
	var middle_y: float = (lane_top_y + lane_bottom_y) * 0.5
	var left: float = lane_center_x - lane_half_width
	var width: float = lane_half_width * 2.0
	if team == MatchTypes.PLAYER_BOTTOM:
		return Rect2(left, middle_y, width, lane_bottom_y - middle_y)
	return Rect2(left, lane_top_y, width, middle_y - lane_top_y)


func is_valid_deploy_position(team: int, world_position: Vector2) -> bool:
	return MatchTypes.is_valid_player_id(team) and get_deploy_rect(team).has_point(world_position)


## Y donde se detienen las unidades del equipo (extremo rival del carril).
func get_lane_end_y(team: int) -> float:
	return lane_top_y if team == MatchTypes.PLAYER_BOTTOM else lane_bottom_y


# --- Castillos ---------------------------------------------------------------

## Y del frente (lado del carril) del castillo de `castle_owner`.
func get_castle_front_y(castle_owner: int) -> float:
	if castle_owner == MatchTypes.PLAYER_TOP:
		return lane_top_y - castle_front_offset
	return lane_bottom_y + castle_front_offset


func is_castle_alive(castle_owner: int) -> bool:
	var player_state: PlayerState = GameManager.get_player_state(castle_owner)
	return player_state != null and player_state.is_castle_alive()


## La unidad tiene el castillo rival vivo dentro de su rango de ataque.
func can_unit_attack_castle(unit: UnitBase) -> bool:
	var castle_owner: int = MatchTypes.opponent_of(unit.team)
	if not is_castle_alive(castle_owner):
		return false
	var distance: float = absf(unit.global_position.y - get_castle_front_y(castle_owner)) - unit.body_radius
	return distance <= unit.attack_range


func queue_castle_hit(attacker: UnitBase, castle_owner: int, amount: float) -> void:
	if attacker == null or attacker.is_dead:
		return
	_pending_hits.append(PendingHit.new(attacker.unit_id, 0, amount, castle_owner))


## Condición de victoria: destruir el castillo rival. Si ambos caen en el
## mismo tick, empate. La decide la autoridad y la comunica GameManager.
func _check_castles() -> void:
	var destroyed: Array[int] = []
	for player_id: int in MatchTypes.PLAYER_COUNT:
		if not is_castle_alive(player_id):
			destroyed.append(player_id)
	if destroyed.size() == MatchTypes.PLAYER_COUNT:
		GameManager.end_match(MatchTypes.NO_PLAYER)
	elif destroyed.size() == 1:
		GameManager.end_match(MatchTypes.opponent_of(destroyed[0]))


## Aplica daño al castillo (sin bajar de 0). Devuelve el daño aplicado.
func damage_castle(castle_owner: int, amount: float) -> float:
	var player_state: PlayerState = GameManager.get_player_state(castle_owner)
	if player_state == null or amount <= 0.0 or not player_state.is_castle_alive():
		return 0.0
	var applied: float = minf(amount, player_state.castle_hp)
	player_state.castle_hp -= applied
	EventBus.castillo_danado.emit(castle_owner, player_state.castle_hp, player_state.castle_max_hp)
	return applied


# --- Consultas ---------------------------------------------------------------

func get_unit(unit_id: int) -> UnitBase:
	return _units_by_id.get(unit_id, null)


func get_alive_units() -> Array[UnitBase]:
	return _units.duplicate()


## Recalcula las estadísticas de las unidades vivas del equipo (p. ej. tras
## comprar un buff). Conserva el % de vida de cada unidad.
func refresh_team_stats(team: int) -> void:
	for unit: UnitBase in _units:
		if unit.team == team:
			unit.refresh_stats(true)


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


## Enemigo vivo de `team` más cercano a la coordenada `origin_y` (distancia en
## el eje del carril hasta el borde de la unidad). Lo usan las torres, que
## están fuera del carril. Desempate determinista: menor unit_id.
func find_nearest_enemy_to_y(team: int, origin_y: float, max_range: float) -> UnitBase:
	var best: UnitBase = null
	var best_distance: float = INF
	for candidate: UnitBase in _units:
		if candidate.team == team or candidate.is_dead:
			continue
		var distance: float = absf(candidate.global_position.y - origin_y) - candidate.body_radius
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


## Proyectil teledirigido a una unidad. source_id es el id lógico de quien
## dispara (unidad o, en la Fase 8, torre).
func spawn_projectile(source_id: int, team: int, origin: Vector2, target_id: int, amount: float, speed: float) -> Projectile:
	if GameManager.match_state == null or get_unit(target_id) == null:
		return null
	return _create_projectile(source_id, team, origin, target_id, amount, speed)


## Proyectil al frente del castillo rival, en línea recta desde `origin`.
func spawn_castle_projectile(source_id: int, team: int, origin: Vector2, amount: float, speed: float) -> Projectile:
	var castle_owner: int = MatchTypes.opponent_of(team)
	if GameManager.match_state == null or not is_castle_alive(castle_owner):
		return null
	var projectile: Projectile = _create_projectile(source_id, team, origin, 0, amount, speed)
	projectile.setup_castle_target(castle_owner, Vector2(origin.x, get_castle_front_y(castle_owner)))
	return projectile


func _create_projectile(source_id: int, team: int, origin: Vector2, target_id: int, amount: float, speed: float) -> Projectile:
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
		var destination: Vector2
		if projectile.targets_castle():
			destination = projectile.target_point
		else:
			var target: UnitBase = get_unit(projectile.target_id)
			if target == null or target.is_dead:
				# El objetivo murió antes de la llegada: el proyectil se pierde.
				_projectiles.remove_at(index)
				projectile.queue_free()
				continue
			destination = target.global_position
		if projectile.simulate_towards(destination, delta):
			_pending_hits.append(PendingHit.new(projectile.source_id, projectile.target_id, projectile.damage, projectile.target_castle_owner))
			_projectiles.remove_at(index)
			projectile.queue_free()
			continue
		index += 1


func _resolve_hits() -> void:
	for hit: PendingHit in _pending_hits:
		if MatchTypes.is_valid_player_id(hit.castle_owner):
			damage_castle(hit.castle_owner, hit.amount)
			continue
		var target: UnitBase = get_unit(hit.target_id)
		if target != null and not target.is_dead:
			target.receive_damage(hit.amount, hit.attacker_id)
	_pending_hits.clear()


func queue_conversion(converter: UnitBase, target: UnitBase) -> void:
	if converter == null or target == null or converter.is_dead:
		return
	_pending_conversions.append(Vector2i(converter.unit_id, target.unit_id))


## Enemigo vivo más cercano en rango con max_hp ≤ max_target_hp.
## Desempate determinista: menor unit_id.
func find_nearest_convertible_enemy(seeker: UnitBase, max_range: float, max_target_hp: float) -> UnitBase:
	var best: UnitBase = null
	var best_distance: float = INF
	for candidate: UnitBase in _units:
		if candidate.team == seeker.team or candidate.is_dead or candidate.max_hp > max_target_hp:
			continue
		var distance: float = seeker.edge_distance_to(candidate)
		if distance > max_range:
			continue
		if distance < best_distance or (is_equal_approx(distance, best_distance) and candidate.unit_id < best.unit_id):
			best = candidate
			best_distance = distance
	return best


## Convierte una unidad al equipo `new_team` sobre la misma instancia.
func convert_unit(unit: UnitBase, new_team: int) -> void:
	if unit == null or unit.is_dead or unit.team == new_team or not MatchTypes.is_valid_player_id(new_team):
		return
	var old_team: int = unit.team
	unit.change_team(new_team)
	var container: Node = _get_container(new_team)
	if unit.get_parent() != container:
		# Diferido: el cambio de padre es solo organizativo/visual.
		unit.reparent.call_deferred(container, true)
	EventBus.unidad_convertida.emit(unit, old_team, new_team)


func _resolve_conversions() -> void:
	for conversion: Vector2i in _pending_conversions:
		# Aunque el convertidor muera en este tick, sigue registrado hasta
		# _process_deaths: la conversión ya estaba decidida y se aplica.
		var converter: UnitBase = get_unit(conversion.x)
		var target: UnitBase = get_unit(conversion.y)
		if converter != null and target != null and not target.is_dead:
			convert_unit(target, converter.team)
	_pending_conversions.clear()


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
	_pending_conversions.clear()
	_group_counter = [0, 0]


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
			"target_castle_owner": projectile.target_castle_owner,
			"position": projectile.global_position,
		})
	return {"units": unit_dicts, "projectiles": projectile_dicts}


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	clear_units()
