extends TestSuite
## Fase 5a: UnitBase + FSM + LaneManager mínimo con Soldier y Tank.

const STEP: float = 1.0 / 60.0

var lane: LaneManager = null
var processor: CommandProcessor = null
var soldier: UnitData = null
var tank: UnitData = null


func before_each() -> void:
	if lane == null:
		lane = LaneManager.new()
		processor = CommandProcessor.new()
		get_root().add_child(lane)
		get_root().add_child(processor)
		processor.register_lane(lane)
		soldier = GameManager.database.get_unit(&"soldier")
		tank = GameManager.database.get_unit(&"tank")
	GameManager.register_command_processor(processor)
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 99)


func after_all() -> void:
	GameManager.register_command_processor(null)
	lane.clear_units()
	lane.queue_free()
	processor.queue_free()


func _run(seconds: float) -> void:
	for _step: int in roundi(seconds / STEP):
		lane.simulate_step(STEP)


func _spawn(data: UnitData, team: int, y: float, x: float = 540.0) -> UnitBase:
	return lane.spawn_unit(data, team, Vector2(x, y))


func test_units_advance_in_their_direction() -> void:
	var ally: UnitBase = _spawn(soldier, 0, 1600.0)
	var enemy: UnitBase = _spawn(soldier, 1, 1000.0)
	_run(1.0)
	assert_true(absf(ally.global_position.y - 1480.0) < 0.5, "aliado sube 120 px/s (y=%.2f)" % ally.global_position.y)
	assert_true(absf(enemy.global_position.y - 1120.0) < 0.5, "enemigo baja 120 px/s (y=%.2f)" % enemy.global_position.y)
	assert_eq(ally.get_state_name(), UnitBase.STATE_ADVANCE, "sin enemigos en rango sigue en ADVANCE")


func test_unit_stops_in_front_of_enemy_castle() -> void:
	var ally: UnitBase = _spawn(soldier, 0, 1000.0)
	_run(2.0)
	var max_y: float = lane.get_castle_front_y(1) + ally.body_radius + ally.attack_range
	assert_true(ally.global_position.y <= max_y and ally.global_position.y >= lane.lane_top_y, "se detiene a distancia de ataque del castillo")
	assert_eq(ally.get_state_name(), UnitBase.STATE_ATTACK, "ataca el castillo")


func test_combat_two_vs_one() -> void:
	# TEST COMBAT: ambos avanzan, detectan, atacan, uno muere, el otro continúa.
	var allies: Array[UnitBase] = lane.spawn_group(soldier, 0, 2)
	var enemy: UnitBase = _spawn(soldier, 1, 1000.0)
	var first_ally: UnitBase = allies[0]
	var states: Array[StringName] = []
	first_ally.state_machine.state_changed.connect(func(_from: StringName, to: StringName) -> void: states.append(to))
	_run(10.0)
	assert_true(enemy.is_dead, "el enemigo muere")
	assert_eq(lane.get_alive_count(1), 0, "sin enemigos vivos")
	assert_eq(lane.get_alive_count(0), 2, "los dos aliados sobreviven")
	assert_eq(states, [UnitBase.STATE_ATTACK, UnitBase.STATE_ADVANCE] as Array[StringName], "ADVANCE → ATTACK → ADVANCE")
	# El enemigo apunta al aliado de menor id y le da 4 golpes (el 4.º, simultáneo a su muerte).
	assert_eq(first_ally.current_hp, 250.0 - 4.0 * 35.0, "vida del aliado golpeado")
	assert_eq(allies[1].current_hp, 250.0, "el otro aliado intacto")
	_run(10.0)
	assert_true(first_ally.can_attack_enemy_castle(), "el superviviente sigue avanzando hasta el castillo rival")


func test_equal_soldiers_trade_simultaneously() -> void:
	var ally: UnitBase = _spawn(soldier, 0, 1600.0)
	var enemy: UnitBase = _spawn(soldier, 1, 1000.0)
	_run(15.0)
	# Golpes simultáneos: 8 × 35 = 280 ≥ 250 en el mismo tick para ambos.
	assert_true(ally.is_dead and enemy.is_dead, "mueren a la vez: sin ventaja por orden de id")


func test_tank_mitigation() -> void:
	var unit: UnitBase = _spawn(tank, 0, 1600.0)
	var applied: float = unit.receive_damage(100.0, 0)
	assert_true(is_equal_approx(applied, 80.0), "recibe incoming × 0.8")
	assert_true(is_equal_approx(unit.current_hp, 770.0), "850 - 80")


func test_tank_beats_soldier() -> void:
	var tank_unit: UnitBase = _spawn(tank, 0, 1600.0)
	var enemy: UnitBase = _spawn(soldier, 1, 1000.0)
	_run(40.0)
	assert_true(enemy.is_dead, "el soldier muere")
	assert_false(tank_unit.is_dead, "el tank sobrevive")


func test_dead_unit_stops_and_is_removed() -> void:
	var ally: UnitBase = _spawn(soldier, 0, 1600.0)
	var enemy: UnitBase = _spawn(soldier, 1, 1540.0)
	var removed: Array[int] = []
	var listener: Callable = func(unidad: CharacterBody2D, _team: int) -> void:
		removed.append((unidad as UnitBase).unit_id)
	EventBus.unidad_eliminada.connect(listener)
	enemy.receive_damage(9999.0, 0)
	assert_eq(enemy.get_state_name(), UnitBase.STATE_DEAD, "ANY → DEAD")
	_run(0.1)
	assert_eq(ally.current_hp, 250.0, "una unidad muerta no ataca")
	assert_true(lane.get_unit(enemy.unit_id) == null, "fuera del registro")
	assert_eq(removed, [enemy.unit_id] as Array[int], "unidad_eliminada una sola vez")
	assert_true(lane.find_nearest_enemy_in_range(ally, 9999.0) == null, "nadie puede apuntar al muerto")
	var y_at_death: float = enemy.global_position.y
	_run(1.0)
	EventBus.unidad_eliminada.disconnect(listener)
	assert_eq(enemy.global_position.y, y_at_death, "el muerto no se mueve")
	assert_true(enemy.is_queued_for_deletion(), "nodo liberado tras la animación")
	assert_eq(removed.size(), 1, "sin eventos duplicados")


func test_nearest_target_selection() -> void:
	var ally: UnitBase = _spawn(soldier, 0, 1500.0)
	var far_enemy: UnitBase = _spawn(soldier, 1, 1440.0)
	var near_enemy: UnitBase = _spawn(soldier, 1, 1460.0)
	assert_true(ally.acquire_target() == near_enemy, "elige el más cercano")
	assert_eq(ally.target_id, near_enemy.unit_id, "target por id")
	assert_true(far_enemy != null, "el lejano también estaba en rango")


func test_target_tie_breaks_by_lowest_id() -> void:
	var ally: UnitBase = _spawn(soldier, 0, 1500.0)
	var first: UnitBase = _spawn(soldier, 1, 1450.0, 500.0)
	_spawn(soldier, 1, 1450.0, 580.0)
	assert_true(ally.acquire_target() == first, "empate → menor unit_id")


func test_out_of_range_not_targeted() -> void:
	var ally: UnitBase = _spawn(soldier, 0, 1600.0)
	_spawn(soldier, 1, 1400.0)
	assert_true(ally.acquire_target() == null, "a 200 px no hay objetivo (rango 45 de borde a borde)")


func test_simulation_is_deterministic() -> void:
	var first_run: Dictionary = _run_scenario()
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 99)
	var second_run: Dictionary = _run_scenario()
	assert_eq(str(first_run), str(second_run), "misma entrada → mismo estado")


func _run_scenario() -> Dictionary:
	lane.spawn_group(soldier, 0, 3)
	lane.spawn_group(soldier, 1, 2)
	_spawn(tank, 1, 1100.0)
	_run(6.0)
	return lane.to_dict()


func test_no_simulation_after_match_end() -> void:
	var ally: UnitBase = _spawn(soldier, 0, 1600.0)
	GameManager.end_match(MatchTypes.NO_PLAYER)
	_run(1.0)
	assert_eq(ally.global_position.y, 1600.0, "partida terminada: nada se mueve")


func test_team_collision_layers() -> void:
	var ally: UnitBase = _spawn(soldier, 0, 1600.0)
	var enemy: UnitBase = _spawn(soldier, 1, 1000.0)
	assert_eq(ally.collision_layer, 2, "team 0 en capa 2")
	assert_eq(enemy.collision_layer, 4, "team 1 en capa 3")
	assert_true(ally.unit_id != enemy.unit_id, "ids lógicos distintos")


func test_spawn_via_debug_command() -> void:
	var deployed: Array[int] = []
	var listener: Callable = func(_unidad: CharacterBody2D, team: int) -> void:
		deployed.append(team)
	EventBus.unidad_desplegada.connect(listener)
	assert_true(GameManager.submit_command(DebugSpawnUnitCommand.new(1, &"soldier", 2)), "comando aceptado")
	assert_false(GameManager.submit_command(DebugSpawnUnitCommand.new(1, &"dragon", 1)), "unidad desconocida")
	EventBus.unidad_desplegada.disconnect(listener)
	assert_eq(lane.get_alive_count(1), 2, "2 soldiers del player 1")
	assert_eq(deployed, [1, 1] as Array[int], "unidad_desplegada por cada una")
	for unit: UnitBase in lane.get_alive_units():
		assert_eq(unit.global_position.y, lane.lane_top_y + lane.spawn_margin, "aparecen en su extremo del carril")


func test_restart_clears_units() -> void:
	_spawn(soldier, 0, 1600.0)
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 100)
	assert_eq(lane.get_alive_units().size(), 0, "nueva partida sin unidades")
