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

## --- Rendimiento ---
## Índice espacial: unidades vivas de cada equipo ordenadas por Y (con sus Y en
## un array plano para buscar por bisección). Se reconstruye/reordena al empezar
## cada tick y solo se usa durante simulate_step; fuera de ahí (tests, IA) las
## consultas recorren todas las unidades. Como el combate es 1D en Y, buscar
## objetivos pasa de O(n) a O(log n + vecinos).
var _team_lists: Array[Array] = []
var _team_ys: Array[PackedFloat32Array] = []
## Desactivarlo (tests, depuración) hace que todas las consultas recorran las
## unidades enteras; el resultado debe ser idéntico.
var use_spatial_index: bool = true
var _index_dirty: bool = true
var _index_active: bool = false
var _index_margin: float = 0.0
var _index_age: int = 0
## Resultado de _select_candidates: lista y tramo [lo, hi) a examinar.
var _query_list: Array[UnitBase] = []
var _query_lo: int = 0
var _query_hi: int = 0
## Candidatos en rango de la consulta en curso (reutilizados: sin asignaciones).
var _scratch_units: Array[UnitBase] = []
var _scratch_distances: PackedFloat64Array = PackedFloat64Array()
## Unidades vivas por equipo (se recalcula solo cuando cambia el registro).
var _alive_counts: Array[int] = [0, 0]
var _counts_dirty: bool = true
## Proyectiles ya usados, listos para reutilizar (evita crear/liberar nodos).
var _projectile_pool: Array[Projectile] = []


func _init() -> void:
	for _team: int in MatchTypes.PLAYER_COUNT:
		var list: Array[UnitBase] = []
		_team_lists.append(list)
		_team_ys.append(PackedFloat32Array())


func _ready() -> void:
	EventBus.partida_iniciada.connect(_on_partida_iniciada)


## Radio en el que un proyectil sin blanco busca otro enemigo.
const PROJECTILE_RETARGET_RANGE: float = 160.0
## Margen sobre el enemigo más cercano dentro del cual se reparten los blancos.
const TARGET_SPREAD_DISTANCE: float = 70.0

## Radio de cuerpo máximo de cualquier unidad y velocidad máxima posible: acotan
## cuánto se puede mover una unidad respecto al índice del inicio del tick.
const MAX_BODY_RADIUS: float = 48.0
const MAX_UNIT_SPEED: float = 400.0
## Cada cuántos ticks se reordena el índice (si nada cambia antes).
const INDEX_REFRESH_TICKS: int = 3
## Proyectiles reutilizables que se conservan.
const PROJECTILE_POOL_LIMIT: int = 96

## Velocidad de interpolación hacia la posición replicada (clientes online).
const NETWORK_LERP_SPEED: float = 12.0


func _physics_process(delta: float) -> void:
	if GameManager.is_authority():
		simulate_step(delta)
	else:
		_client_visual_step(delta)


func simulate_step(delta: float) -> void:
	if delta <= 0.0 or not GameManager.is_authority() or not GameManager.is_match_running():
		return
	_lap(&"")
	_refresh_index(delta)
	_lap(&"indice")
	for unit: UnitBase in _units:
		unit.simulate(delta)
	_lap(&"unidades")
	_simulate_projectiles(delta)
	_lap(&"proyectiles")
	_index_active = false
	_resolve_hits()
	_resolve_heals()
	_resolve_conversions()
	_lap(&"golpes_y_curas")
	_process_deaths()
	_update_dying(delta)
	_check_castles()
	_lap(&"muertes")


## Medición por fases de simulate_step (tools/PerfBench). Desactivado por
## defecto: cuando está en false _lap() no hace nada.
var profiling_enabled: bool = false
var profile_us: Dictionary = {}
var _lap_started: int = 0


func _lap(phase: StringName) -> void:
	if not profiling_enabled:
		return
	var now: int = Time.get_ticks_usec()
	if phase != &"":
		profile_us[phase] = int(profile_us.get(phase, 0)) + now - _lap_started
	_lap_started = now


# --- Aparición -------------------------------------------------------------

func spawn_unit(unit_data: UnitData, team: int, world_position: Vector2) -> UnitBase:
	if unit_data == null or not MatchTypes.is_valid_player_id(team) or GameManager.match_state == null:
		push_error("LaneManager.spawn_unit: parámetros inválidos")
		return null
	if get_alive_count(team) >= get_unit_cap():
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


## Tropas vivas máximas por bando (regla max_units_per_team).
func get_unit_cap() -> int:
	var rules: GameRules = GameManager.get_rules()
	return rules.max_units_per_team if rules != null else 80


func get_alive_count(team: int) -> int:
	if _counts_dirty:
		_alive_counts = [0, 0]
		for unit: UnitBase in _units:
			if MatchTypes.is_valid_player_id(unit.team):
				_alive_counts[unit.team] += 1
		_counts_dirty = false
	return _alive_counts[team] if MatchTypes.is_valid_player_id(team) else 0


## El registro de unidades cambió (aparece, muere, se convierte): el índice
## espacial y los contadores se rehacen en la próxima consulta.
func _mark_units_changed() -> void:
	_index_dirty = true
	_counts_dirty = true


## Deja el índice listo para este tick: membresía (solo si hubo cambios) y
## orden por Y (inserción: casi siempre ya está ordenado).
func _refresh_index(delta: float) -> void:
	# Reordenar cada INDEX_REFRESH_TICKS ticks basta: el margen de búsqueda cubre
	# lo que una unidad se mueve entre reordenaciones. Un cambio de registro
	# (aparece/muere/se convierte) fuerza reordenar ya.
	if not use_spatial_index:
		_index_active = false
		return
	_index_age += 1
	if not _index_dirty and _index_age < INDEX_REFRESH_TICKS:
		_index_active = true
		return
	_index_age = 0
	if _index_dirty:
		for team: int in MatchTypes.PLAYER_COUNT:
			_team_lists[team].clear()
		for unit: UnitBase in _units:
			if not unit.is_dead and MatchTypes.is_valid_player_id(unit.team):
				_team_lists[unit.team].append(unit)
		_index_dirty = false
	for team: int in MatchTypes.PLAYER_COUNT:
		var list: Array[UnitBase] = _team_lists[team]
		var ys: PackedFloat32Array = _team_ys[team]
		ys.resize(list.size())
		for index: int in list.size():
			var unit: UnitBase = list[index]
			var y: float = unit.global_position.y
			var slot: int = index - 1
			while slot >= 0 and ys[slot] > y:
				list[slot + 1] = list[slot]
				ys[slot + 1] = ys[slot]
				slot -= 1
			list[slot + 1] = unit
			ys[slot + 1] = y
		_team_ys[team] = ys
	_index_margin = MAX_UNIT_SPEED * maxf(delta, 0.0) * INDEX_REFRESH_TICKS + 2.0
	_index_active = true


## Prepara en _query_list/_query_lo/_query_hi las unidades que PODRÍAN estar a
## menos de `half_window` en Y de `y`. `team` = -1 para todas. Sin índice
## activo devuelve todas las unidades. Quien lo llame sigue filtrando por
## equipo y distancia exacta, así que el resultado es idéntico al recorrido
## completo: el índice solo descarta candidatos imposibles.
func _select_candidates(team: int, y: float, half_window: float) -> void:
	if not _index_active or team < 0:
		_query_list = _units
		_query_lo = 0
		_query_hi = _units.size()
		return
	var ys: PackedFloat32Array = _team_ys[team]
	var reach: float = half_window + _index_margin
	_query_list = _team_lists[team]
	_query_lo = ys.bsearch(y - reach, true)
	_query_hi = ys.bsearch(y + reach, false)


## Enemigo vivo cercano (distancia de borde a borde) dentro de max_range.
## Entre los que están a menos de TARGET_SPREAD_DISTANCE del más cercano el
## buscador elige uno según un hash de su unit_id y el del candidato: los
## blancos se reparten y un ejército no concentra todos los golpes en uno solo
## (sobredaño). Determinista y independiente del orden en que se recorran.
func find_nearest_enemy_in_range(seeker: UnitBase, max_range: float) -> UnitBase:
	var seeker_team: int = seeker.team
	var seeker_y: float = seeker.global_position.y
	var seeker_radius: float = seeker.body_radius
	_select_candidates(MatchTypes.opponent_of(seeker_team), seeker_y, max_range + seeker_radius + MAX_BODY_RADIUS)
	var list: Array[UnitBase] = _query_list
	_scratch_units.clear()
	_scratch_distances.clear()
	var best_distance: float = INF
	for index: int in range(_query_lo, _query_hi):
		var candidate: UnitBase = list[index]
		if candidate.team == seeker_team or candidate.is_dead:
			continue
		var distance: float = absf(candidate.global_position.y - seeker_y) - (seeker_radius + candidate.body_radius)
		if distance > max_range:
			continue
		_scratch_units.append(candidate)
		_scratch_distances.append(distance)
		if distance < best_distance:
			best_distance = distance
	if _scratch_units.is_empty():
		return null
	var limit: float = minf(best_distance + TARGET_SPREAD_DISTANCE, max_range)
	var chosen: UnitBase = null
	var chosen_key: int = 0
	for index: int in _scratch_units.size():
		if _scratch_distances[index] > limit:
			continue
		var candidate: UnitBase = _scratch_units[index]
		var key: int = ((candidate.unit_id * 73856093) ^ (seeker.unit_id * 19349663)) & 0x7FFFFFFF
		if chosen == null or key < chosen_key or (key == chosen_key and candidate.unit_id < chosen.unit_id):
			chosen = candidate
			chosen_key = key
	return chosen


static func _compare_unit_ids(a: UnitBase, b: UnitBase) -> bool:
	return a.unit_id < b.unit_id


## Enemigo vivo de `team` más cercano a la coordenada `origin_y` (distancia en
## el eje del carril hasta el borde de la unidad). Lo usan las torres, que
## están fuera del carril. Desempate determinista: menor unit_id.
func find_nearest_enemy_to_y(team: int, origin_y: float, max_range: float) -> UnitBase:
	var best: UnitBase = null
	var best_distance: float = INF
	_select_candidates(MatchTypes.opponent_of(team), origin_y, max_range + MAX_BODY_RADIUS)
	var list: Array[UnitBase] = _query_list
	var lo: int = _query_lo
	var hi: int = _query_hi
	for index: int in range(lo, hi):
		var candidate: UnitBase = list[index]
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
	var seeker_y: float = seeker.global_position.y
	var seeker_radius: float = seeker.body_radius
	_select_candidates(seeker.team, seeker_y, max_range + seeker_radius + MAX_BODY_RADIUS)
	var list: Array[UnitBase] = _query_list
	var lo: int = _query_lo
	var hi: int = _query_hi
	for index: int in range(lo, hi):
		var candidate: UnitBase = list[index]
		if candidate == seeker or candidate.team != seeker.team or candidate.is_dead or candidate.current_hp >= candidate.max_hp:
			continue
		if absf(candidate.global_position.y - seeker_y) - (seeker_radius + candidate.body_radius) > max_range:
			continue
		var ratio: float = candidate.current_hp / candidate.max_hp
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
	var projectile: Projectile = _acquire_projectile()
	projectile.setup(GameManager.match_state.allocate_entity_id(), source_id, team, target_id, amount, speed)
	projectile.global_position = origin
	_projectiles.append(projectile)
	return projectile


## Un proyectil listo para usar: reutiliza uno del pool o crea uno nuevo.
func _acquire_projectile() -> Projectile:
	var projectile: Projectile = _projectile_pool.pop_back() if not _projectile_pool.is_empty() else null
	if projectile == null:
		projectile = Projectile.new()
		var container: Node = projectiles_container if projectiles_container != null else self
		container.add_child(projectile)
	projectile.visible = true
	return projectile


## Devuelve el proyectil al pool (oculto) o lo libera si el pool está lleno.
func _release_projectile(projectile: Projectile) -> void:
	if _projectile_pool.size() >= PROJECTILE_POOL_LIMIT:
		projectile.queue_free()
		return
	projectile.visible = false
	_projectile_pool.append(projectile)


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
				# El objetivo murió en vuelo: busca otro enemigo cercano y, si no
				# hay ninguno, el proyectil se pierde. Sin esto, los ejércitos
				# grandes desperdiciaban casi todas las flechas en un solo blanco.
				target = find_nearest_enemy_to_y(projectile.team, projectile.global_position.y, PROJECTILE_RETARGET_RANGE)
				if target == null:
					_projectiles.remove_at(index)
					_release_projectile(projectile)
					continue
				projectile.target_id = target.unit_id
			destination = target.global_position
		if projectile.simulate_towards(destination, delta):
			_pending_hits.append(PendingHit.new(projectile.source_id, projectile.target_id, projectile.damage, projectile.target_castle_owner))
			_projectiles.remove_at(index)
			_release_projectile(projectile)
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
	_select_candidates(MatchTypes.opponent_of(seeker.team), seeker.global_position.y, max_range + seeker.body_radius + MAX_BODY_RADIUS)
	var list: Array[UnitBase] = _query_list
	var lo: int = _query_lo
	var hi: int = _query_hi
	for index: int in range(lo, hi):
		var candidate: UnitBase = list[index]
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
	_mark_units_changed()
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
		_mark_units_changed()
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
	_mark_units_changed()


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
	for projectile: Projectile in _projectile_pool:
		projectile.queue_free()
	_projectile_pool.clear()
	_mark_units_changed()
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
			"team": projectile.team,
			"target_id": projectile.target_id,
			"target_castle_owner": projectile.target_castle_owner,
			"position": projectile.global_position,
		})
	return {"units": unit_dicts, "projectiles": projectile_dicts}


## Estado del carril para red y repeticiones, en arrays planos (unas 8 veces
## más pequeño que to_dict, que queda para depuración y tests de determinismo):
##   ui: [unit_id, team, índice en ut] por unidad     ut: tipos de unidad presentes
##   uf: [x, y, vida, vida_máx] por unidad
##   pi: [projectile_id, source_id, team] por proyectil   pf: [x, y] por proyectil
func to_snapshot() -> Dictionary:
	var unit_ids: PackedInt32Array = PackedInt32Array()
	var unit_floats: PackedFloat32Array = PackedFloat32Array()
	var types: PackedStringArray = PackedStringArray()
	unit_ids.resize(_units.size() * 3)
	unit_floats.resize(_units.size() * 4)
	for index: int in _units.size():
		var unit: UnitBase = _units[index]
		var type_index: int = types.find(str(unit.data.id))
		if type_index < 0:
			type_index = types.size()
			types.append(str(unit.data.id))
		unit_ids[index * 3] = unit.unit_id
		unit_ids[index * 3 + 1] = unit.team
		unit_ids[index * 3 + 2] = type_index
		var position_now: Vector2 = unit.global_position
		unit_floats[index * 4] = position_now.x
		unit_floats[index * 4 + 1] = position_now.y
		unit_floats[index * 4 + 2] = unit.current_hp
		unit_floats[index * 4 + 3] = unit.max_hp
	var projectile_ids: PackedInt32Array = PackedInt32Array()
	var projectile_floats: PackedFloat32Array = PackedFloat32Array()
	projectile_ids.resize(_projectiles.size() * 3)
	projectile_floats.resize(_projectiles.size() * 2)
	for index: int in _projectiles.size():
		var projectile: Projectile = _projectiles[index]
		projectile_ids[index * 3] = projectile.projectile_id
		projectile_ids[index * 3 + 1] = projectile.source_id
		projectile_ids[index * 3 + 2] = projectile.team
		projectile_floats[index * 2] = projectile.global_position.x
		projectile_floats[index * 2 + 1] = projectile.global_position.y
	return {"ui": unit_ids, "uf": unit_floats, "ut": types, "pi": projectile_ids, "pf": projectile_floats}


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	clear_units()


# --- Cliente online (solo presentación) ------------------------------------------

## Aplica el estado replicado (formato de to_snapshot): crea, actualiza o retira
## unidades y proyectiles por id lógico. El cliente nunca simula combate: solo
## presenta.
func apply_snapshot(data: Dictionary) -> void:
	var unit_ids: PackedInt32Array = data.get("ui", PackedInt32Array())
	var unit_floats: PackedFloat32Array = data.get("uf", PackedFloat32Array())
	var types: PackedStringArray = data.get("ut", PackedStringArray())
	var seen_units: Dictionary[int, bool] = {}
	for index: int in unit_ids.size() / 3:
		var unit_id: int = unit_ids[index * 3]
		var team: int = unit_ids[index * 3 + 1]
		var network_pos: Vector2 = Vector2(unit_floats[index * 4], unit_floats[index * 4 + 1])
		seen_units[unit_id] = true
		var unit: UnitBase = get_unit(unit_id)
		var announce_health: bool = false
		if unit == null:
			var type_index: int = unit_ids[index * 3 + 2]
			unit = _create_replicated_unit(unit_id, team, StringName(types[type_index]) if type_index < types.size() else &"", network_pos)
			if unit == null:
				continue
		else:
			announce_health = true
			if unit.team != team:
				convert_unit(unit, team)
		unit.network_position = network_pos
		unit.apply_network_health(unit_floats[index * 4 + 2], unit_floats[index * 4 + 3], announce_health)
	var index: int = 0
	while index < _units.size():
		var existing: UnitBase = _units[index]
		if seen_units.has(existing.unit_id):
			index += 1
			continue
		existing.die()
		_units.remove_at(index)
		_units_by_id.erase(existing.unit_id)
		_dying.append(existing)
		_mark_units_changed()
	_apply_projectile_snapshot(data.get("pi", PackedInt32Array()), data.get("pf", PackedFloat32Array()))


func _create_replicated_unit(unit_id: int, team: int, unit_type: StringName, network_pos: Vector2) -> UnitBase:
	var unit_data: UnitData = GameManager.database.get_unit(unit_type) if GameManager.database != null else null
	if unit_data == null or not MatchTypes.is_valid_player_id(team):
		return null
	var unit: UnitBase = UnitBase.new()
	unit.setup(unit_id, team, unit_data, self)
	_get_container(team).add_child(unit)
	unit.global_position = network_pos
	unit.network_position = network_pos
	_units.append(unit)
	# Los ids llegan casi siempre crecientes: solo se reordena si no es así.
	if _units.size() > 1 and _units[_units.size() - 2].unit_id > unit_id:
		_units.sort_custom(_compare_unit_ids)
	_units_by_id[unit_id] = unit
	_mark_units_changed()
	return unit


func _apply_projectile_snapshot(projectile_ids: PackedInt32Array, projectile_floats: PackedFloat32Array) -> void:
	var by_id: Dictionary[int, Projectile] = {}
	for projectile: Projectile in _projectiles:
		by_id[projectile.projectile_id] = projectile
	var kept: Array[Projectile] = []
	for index: int in projectile_ids.size() / 3:
		var projectile_id: int = projectile_ids[index * 3]
		var network_pos: Vector2 = Vector2(projectile_floats[index * 2], projectile_floats[index * 2 + 1])
		var projectile: Projectile = by_id.get(projectile_id, null)
		if projectile == null:
			projectile = _acquire_projectile()
			projectile.setup(projectile_id, projectile_ids[index * 3 + 1], projectile_ids[index * 3 + 2], 0, 0.0, 0.0)
			projectile.global_position = network_pos
		by_id.erase(projectile_id)
		projectile.target_point = network_pos
		kept.append(projectile)
	for leftover: Projectile in by_id.values():
		_release_projectile(leftover)
	_projectiles = kept


func _client_visual_step(delta: float) -> void:
	var weight: float = clampf(delta * NETWORK_LERP_SPEED, 0.0, 1.0)
	for unit: UnitBase in _units:
		unit.global_position = unit.global_position.lerp(unit.network_position, weight)
	for projectile: Projectile in _projectiles:
		projectile.global_position = projectile.global_position.lerp(projectile.target_point, weight)
	_update_dying(delta)
