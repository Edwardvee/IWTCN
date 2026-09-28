extends TestSuite
## Fase 12: castillo destruido = fin de partida (victoria / derrota / empate).

const STEP: float = 1.0 / 60.0

var processor: CommandProcessor = null
var lane: LaneManager = null
var soldier: UnitData = null
var results: Array[int] = []


func before_each() -> void:
	if processor == null:
		processor = CommandProcessor.new()
		lane = LaneManager.new()
		get_root().add_child(processor)
		get_root().add_child(lane)
		processor.register_lane(lane)
		soldier = GameManager.database.get_unit(&"soldier")
		EventBus.partida_terminada.connect(_on_partida_terminada)
	GameManager.register_command_processor(processor)
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 1212)
	results.clear()


func after_all() -> void:
	EventBus.partida_terminada.disconnect(_on_partida_terminada)
	GameManager.register_command_processor(null)
	lane.clear_units()
	processor.queue_free()
	lane.queue_free()


func _on_partida_terminada(ganador_player_id: int) -> void:
	results.append(ganador_player_id)


func _run(seconds: float) -> void:
	for _step: int in roundi(seconds / STEP):
		lane.simulate_step(STEP)


func test_destroying_enemy_castle_is_victory() -> void:
	lane.damage_castle(1, 2960.0)
	lane.spawn_unit(soldier, 0, Vector2(540.0, 960.0))
	_run(3.0)
	assert_false(GameManager.is_match_running(), "partida terminada")
	assert_eq(GameManager.match_state.winner_player_id, 0, "gana el player 0")
	assert_eq(results, [0] as Array[int], "partida_terminada(0) una sola vez")


func test_losing_own_castle_is_defeat() -> void:
	lane.damage_castle(0, 2960.0)
	lane.spawn_unit(soldier, 1, Vector2(540.0, 2240.0))
	_run(3.0)
	assert_eq(GameManager.match_state.winner_player_id, 1, "gana el rival")
	assert_eq(results, [1] as Array[int], "derrota del player 0")


func test_both_castles_same_tick_is_draw() -> void:
	lane.damage_castle(0, 3000.0)
	lane.damage_castle(1, 3000.0)
	lane.simulate_step(STEP)
	assert_eq(results, [MatchTypes.NO_PLAYER] as Array[int], "empate")


func test_debug_command_destroys_castle() -> void:
	for _i: int in 3:
		GameManager.submit_command(DebugDamageCastleCommand.new(1, 1000.0))
	lane.simulate_step(STEP)
	assert_eq(results, [0] as Array[int], "3 × 1000 → victoria")


func test_everything_freezes_after_end() -> void:
	var ally: UnitBase = lane.spawn_unit(soldier, 0, Vector2(540.0, 2000.0))
	lane.damage_castle(1, 3000.0)
	lane.simulate_step(STEP)
	var y_at_end: float = ally.global_position.y
	var gold_at_end: int = EconomyManager.get_gold(0)
	_run(5.0)
	EconomyManager.simulate_step(5.0)
	assert_eq(ally.global_position.y, y_at_end, "las unidades no se mueven")
	assert_eq(EconomyManager.get_gold(0), gold_at_end, "sin ingresos")
	assert_false(GameManager.submit_command(DebugSpawnUnitCommand.new(0, &"soldier", 1)), "comandos rechazados")
	GameManager.end_match(1)
	assert_eq(results, [0] as Array[int], "el resultado no cambia después")


func test_result_in_snapshot_and_restart() -> void:
	lane.damage_castle(1, 3000.0)
	lane.simulate_step(STEP)
	assert_eq(GameManager.match_state.to_dict()["winner_player_id"], 0, "ganador en el snapshot")
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 1213)
	assert_true(GameManager.is_match_running(), "nueva partida en curso")
	assert_eq(GameManager.match_state.winner_player_id, MatchTypes.NO_PLAYER, "sin ganador")
	assert_true(lane.is_castle_alive(1), "castillos restaurados")
