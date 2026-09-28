extends TestSuite
## Fase 6: interacción con castillos, zonas de despliegue y aparición en grupo.

const STEP: float = 1.0 / 60.0

var lane: LaneManager = null
var soldier: UnitData = null
var archer: UnitData = null
var priest: UnitData = null


func before_each() -> void:
	if lane == null:
		lane = LaneManager.new()
		get_root().add_child(lane)
		soldier = GameManager.database.get_unit(&"soldier")
		archer = GameManager.database.get_unit(&"archer")
		priest = GameManager.database.get_unit(&"priest")
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 606)


func after_all() -> void:
	lane.clear_units()
	lane.queue_free()


func _run(seconds: float) -> void:
	for _step: int in roundi(seconds / STEP):
		lane.simulate_step(STEP)


func _spawn(data: UnitData, team: int, y: float, x: float = 540.0) -> UnitBase:
	return lane.spawn_unit(data, team, Vector2(x, y))


func _castle_hp(owner_id: int) -> float:
	return GameManager.get_player_state(owner_id).castle_hp


func test_castles_start_full() -> void:
	assert_eq(_castle_hp(0), 3000.0, "castillo player 0")
	assert_eq(_castle_hp(1), 3000.0, "castillo player 1")


func test_soldier_attacks_enemy_castle_at_lane_end() -> void:
	var events: Array[float] = []
	var listener: Callable = func(player_id: int, vida_actual: float, _vida_maxima: float) -> void:
		if player_id == 1:
			events.append(vida_actual)
	EventBus.castillo_danado.connect(listener)
	var ally: UnitBase = _spawn(soldier, 0, 1000.0)
	_run(5.0)
	EventBus.castillo_danado.disconnect(listener)
	var stop_y: float = lane.get_castle_front_y(1) + ally.body_radius + ally.attack_range
	assert_true(absf(ally.global_position.y - stop_y) < 3.0, "se para a su rango del castillo (y=%.1f)" % ally.global_position.y)
	assert_eq(ally.get_state_name(), UnitBase.STATE_ATTACK, "ATTACK sobre el castillo")
	# Llega a ~0.45 s y golpea cada 1.2 s: 4 golpes en 5 s.
	assert_eq(_castle_hp(1), 3000.0 - 4.0 * 35.0, "4 golpes de 35")
	assert_eq(events, [2965.0, 2930.0, 2895.0, 2860.0] as Array[float], "castillo_danado por cada golpe")
	assert_eq(_castle_hp(0), 3000.0, "el castillo propio intacto")


func test_enemy_team_attacks_player_castle() -> void:
	_spawn(soldier, 1, 2200.0)
	_run(3.0)
	assert_true(_castle_hp(0) < 3000.0, "el rival también daña mi castillo")


func test_units_have_priority_over_castle() -> void:
	var ally: UnitBase = _spawn(soldier, 0, 1000.0)
	_run(2.0)
	var castle_before: float = _castle_hp(1)
	var defender: UnitBase = _spawn(soldier, 1, 960.0)
	_run(0.1)
	assert_eq(ally.target_id, defender.unit_id, "cambia al enemigo en rango")
	_run(1.0)
	assert_eq(_castle_hp(1), castle_before, "no golpea el castillo mientras haya enemigo en rango")


func test_archer_shoots_castle_from_range() -> void:
	var shooter: UnitBase = _spawn(archer, 0, 1400.0)
	_run(4.0)
	var stop_y: float = lane.get_castle_front_y(1) + shooter.body_radius + shooter.attack_range
	assert_true(absf(shooter.global_position.y - stop_y) < 3.0, "se para a su rango del castillo (y=%.1f)" % shooter.global_position.y)
	assert_true(_castle_hp(1) < 3000.0, "sus proyectiles dañan el castillo")
	assert_eq(fmod(3000.0 - _castle_hp(1), 42.0), 0.0, "daño en múltiplos de 42")


func test_castle_never_below_zero() -> void:
	lane.damage_castle(1, 2990.0)
	_spawn(soldier, 0, 920.0)
	_run(3.0)
	assert_eq(_castle_hp(1), 0.0, "vida mínima 0")
	assert_false(lane.is_castle_alive(1), "castillo destruido")
	assert_eq(lane.damage_castle(1, 50.0), 0.0, "un castillo destruido no recibe más daño")


func test_priest_never_attacks_castle() -> void:
	_spawn(priest, 0, 920.0)
	_run(3.0)
	assert_eq(_castle_hp(1), 3000.0, "el Priest no daña el castillo")


func test_deploy_zone_is_own_half() -> void:
	assert_true(lane.is_valid_deploy_position(0, Vector2(540.0, 2000.0)), "P0 en su mitad")
	assert_false(lane.is_valid_deploy_position(0, Vector2(540.0, 1200.0)), "P0 en la mitad rival")
	assert_false(lane.is_valid_deploy_position(0, Vector2(100.0, 2000.0)), "P0 fuera del carril")
	assert_true(lane.is_valid_deploy_position(1, Vector2(540.0, 1200.0)), "P1 en su mitad")
	assert_false(lane.is_valid_deploy_position(1, Vector2(540.0, 2000.0)), "P1 en la mitad rival")
	assert_false(lane.is_valid_deploy_position(7, Vector2(540.0, 2000.0)), "jugador inválido")


func test_spawn_group_at_point() -> void:
	var units: Array[UnitBase] = lane.spawn_group_at(soldier, 0, 3, Vector2(540.0, 2000.0))
	assert_eq(units.size(), 3, "3 unidades")
	for unit: UnitBase in units:
		assert_eq(unit.global_position.y, 2000.0, "misma fila en el punto")
		assert_true(lane.is_valid_deploy_position(0, unit.global_position), "dentro del carril")


func test_large_group_uses_rows_behind() -> void:
	var units: Array[UnitBase] = lane.spawn_group_at(soldier, 0, 6, Vector2(540.0, 2000.0))
	assert_eq(units[0].global_position.y, 2000.0, "primera fila")
	assert_eq(units[5].global_position.y, 2000.0 + LaneManager.SPAWN_SPACING_Y, "segunda fila detrás (player 0 = más abajo)")


func test_consecutive_groups_do_not_overlap() -> void:
	var first: Array[UnitBase] = lane.spawn_group(soldier, 0, 1)
	var second: Array[UnitBase] = lane.spawn_group(soldier, 0, 1)
	assert_true(first[0].global_position != second[0].global_position, "grupos seguidos escalonados")


func test_snapshot_includes_castle_hp() -> void:
	lane.damage_castle(0, 100.0)
	var players: Array = GameManager.match_state.to_dict()["players"]
	assert_eq((players[0] as Dictionary)["castle_hp"], 2900.0, "castle_hp en el snapshot")


func test_restart_resets_castles() -> void:
	lane.damage_castle(1, 500.0)
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 607)
	assert_eq(_castle_hp(1), 3000.0, "nueva partida con castillos llenos")
