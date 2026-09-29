extends TestSuite
## Optimizaciones de rendimiento: deben dar el MISMO resultado que la versión
## simple (índice espacial, contadores en caché, pool de proyectiles,
## snapshots compactos e incrementales).

const STEP: float = 1.0 / 60.0

var processor: CommandProcessor = null
var draft: DraftManager = null
var lane: LaneManager = null
var grid0: GridManager = null
var grid1: GridManager = null
var replicator: StateReplicator = null


func before_each() -> void:
	if processor == null:
		_build_fixture()
	lane.use_spatial_index = true
	GameManager.register_command_processor(processor)
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 606)


func after_all() -> void:
	GameManager.register_command_processor(null)
	lane.clear_units()
	for node: Node in [processor, draft, lane, grid0, grid1, replicator]:
		node.queue_free()


func _build_fixture() -> void:
	processor = CommandProcessor.new()
	draft = DraftManager.new()
	lane = LaneManager.new()
	grid0 = GridManager.new()
	grid0.player_id = 0
	grid0.position = Vector2(30.0, 2460.0)
	grid1 = GridManager.new()
	grid1.player_id = 1
	grid1.position = Vector2(30.0, 40.0)
	replicator = StateReplicator.new()
	for node: Node in [processor, draft, lane, grid0, grid1, replicator]:
		get_root().add_child(node)
	for grid: GridManager in [grid0, grid1]:
		grid.lane = lane
		processor.register_grid(grid)
	processor.register_lane(lane)
	processor.register_draft(draft)
	replicator.setup(lane, [grid0, grid1])


## Batalla con todos los tipos de unidad, proyectiles, curas y una conversión.
func _run_battle(seconds: float) -> String:
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 606)
	GameManager.get_rules().max_units_per_team = 200
	for team: int in MatchTypes.PLAYER_COUNT:
		for unit_id: StringName in [&"soldier", &"archer", &"priest", &"tank", &"soldier", &"archer"]:
			var origin: Vector2 = Vector2(540.0, 1650.0 + (350.0 if team == 0 else -350.0))
			lane.spawn_group_at(GameManager.database.get_unit(unit_id), team, 4, origin)
	for _step: int in roundi(seconds / STEP):
		if not GameManager.is_match_running():
			break
		GameManager.match_state.match_time += STEP
		lane.simulate_step(STEP)
	GameManager.get_rules().max_units_per_team = 80
	return "%s|%s|%s" % [str(lane.to_dict()), GameManager.get_player_state(0).castle_hp, GameManager.get_player_state(1).castle_hp]


func test_spatial_index_gives_identical_results() -> void:
	lane.use_spatial_index = false
	var simple: String = _run_battle(25.0)
	lane.use_spatial_index = true
	var indexed: String = _run_battle(25.0)
	assert_true(simple.length() > 200, "la batalla produjo estado (%d caracteres)" % simple.length())
	assert_true(simple == indexed, "con y sin índice espacial la batalla acaba exactamente igual")


func test_alive_count_cache_follows_spawn_death_and_conversion() -> void:
	var soldier: UnitData = GameManager.database.get_unit(&"soldier")
	assert_eq(lane.get_alive_count(0), 0, "vacío")
	var first: UnitBase = lane.spawn_unit(soldier, 0, Vector2(540.0, 2000.0))
	lane.spawn_unit(soldier, 0, Vector2(540.0, 2010.0))
	var enemy: UnitBase = lane.spawn_unit(soldier, 1, Vector2(540.0, 1200.0))
	assert_eq(lane.get_alive_count(0), 2, "dos aliados")
	assert_eq(lane.get_alive_count(1), 1, "un enemigo")
	lane.convert_unit(enemy, 0)
	assert_eq(lane.get_alive_count(0), 3, "el convertido cuenta para su nuevo equipo")
	assert_eq(lane.get_alive_count(1), 0, "y deja de contar en el anterior")
	first.receive_damage(99999.0, 0)
	lane.simulate_step(STEP)
	assert_eq(lane.get_alive_count(0), 2, "el muerto sale del contador")
	lane.clear_units()
	assert_eq(lane.get_alive_count(0), 0, "clear_units vacía los contadores")
	assert_eq(lane.get_alive_count(-1), 0, "equipo inválido = 0")


func test_projectiles_are_recycled() -> void:
	var archer: UnitData = GameManager.database.get_unit(&"archer")
	var soldier: UnitData = GameManager.database.get_unit(&"soldier")
	lane.spawn_unit(archer, 0, Vector2(540.0, 1500.0))
	var victim: UnitBase = lane.spawn_unit(soldier, 1, Vector2(540.0, 1400.0))
	victim.receive_damage(200.0, 0)
	var seen_projectiles: Dictionary = {}
	for _step: int in 1200:
		lane.simulate_step(STEP)
		for node: Node in lane.get_children():
			if node is Projectile:
				seen_projectiles[node.get_instance_id()] = true
		if victim.is_dead:
			break
	assert_true(victim.is_dead, "los flechazos matan al objetivo")
	assert_true(seen_projectiles.size() >= 1, "se dispararon proyectiles")
	# Una vez todos terminados, están ocultos en el pool y no quedan en vuelo.
	assert_eq(lane.get_projectile_count(), 0, "ningún proyectil en vuelo")
	var visible_projectiles: int = 0
	for node: Node in lane.get_children():
		if node is Projectile and (node as Projectile).visible:
			visible_projectiles += 1
	assert_eq(visible_projectiles, 0, "los proyectiles usados se ocultan y se reutilizan")


func test_recycled_projectile_is_fully_reset() -> void:
	var projectile: Projectile = lane.spawn_castle_projectile(1, 0, Vector2(540.0, 2000.0), 10.0, 900.0)
	assert_true(projectile != null and projectile.targets_castle(), "proyectil al castillo")
	lane.clear_units()
	var target: UnitBase = lane.spawn_unit(GameManager.database.get_unit(&"soldier"), 0, Vector2(540.0, 2000.0))
	var unit_projectile: Projectile = lane.spawn_projectile(2, 1, Vector2(540.0, 1500.0), target.unit_id, 20.0, 700.0)
	assert_false(unit_projectile.targets_castle(), "un proyectil nuevo a unidad no hereda el objetivo de castillo")
	assert_eq(unit_projectile.team, 1, "equipo actualizado")
	assert_eq(unit_projectile.damage, 20.0, "daño actualizado")


# --- Snapshots compactos e incrementales ----------------------------------------

func test_lane_snapshot_is_compact() -> void:
	var soldier: UnitData = GameManager.database.get_unit(&"soldier")
	lane.spawn_group_at(soldier, 0, 20, Vector2(540.0, 2000.0))
	lane.spawn_group_at(soldier, 1, 20, Vector2(540.0, 1200.0))
	var compact: int = var_to_bytes(lane.to_snapshot()).size()
	var verbose: int = var_to_bytes(lane.to_dict()).size()
	assert_true(compact * 4 < verbose, "el snapshot compacto ocupa menos de la cuarta parte (%d vs %d bytes)" % [compact, verbose])


func test_delta_snapshot_omits_unchanged_and_sends_changes() -> void:
	var cache: Dictionary = {}
	var first: Dictionary = replicator.build_delta_snapshot(cache)
	var first_player: Dictionary = first["match"]["players"][0]
	assert_true(first_player.has("grid") and first_player.has("shop") and first_player.has("buffs"), "el primero va completo")
	var second: Dictionary = replicator.build_delta_snapshot(cache)
	var second_player: Dictionary = second["match"]["players"][0]
	assert_false(second_player.has("grid") or second_player.has("shop") or second_player.has("buffs"), "sin cambios se omite lo pesado")
	assert_true(second_player.has("gold") and second_player.has("castle_hp"), "el oro y el castillo siempre van")
	EconomyManager.add_gold(0, 200)
	GameManager.submit_command(BuildCommand.new(0, &"card_farm", 16, GameCommand.Source.DEBUG))
	var third: Dictionary = replicator.build_delta_snapshot(cache)
	assert_true((third["match"]["players"][0] as Dictionary).has("grid"), "un edificio nuevo vuelve a enviar la cuadrícula")
	assert_false((third["match"]["players"][1] as Dictionary).has("grid"), "la del rival sigue omitida")
	assert_false((first["match"] as Dictionary).has("random"), "no se envía el estado del azar")


func test_client_keeps_state_when_delta_omits_it() -> void:
	# Servidor: construye y toma un snapshot completo + uno incremental.
	EconomyManager.add_gold(0, 300)
	GameManager.submit_command(BuildCommand.new(0, &"card_farm", 16, GameCommand.Source.DEBUG))
	var cache: Dictionary = {}
	var full: Dictionary = replicator.build_delta_snapshot(cache)
	var partial: Dictionary = replicator.build_delta_snapshot(cache)
	var expected_grid: String = str(GameManager.get_player_state(0).grid.to_dict())
	var expected_offer: Array[StringName] = GameManager.get_player_state(0).shop.offer.duplicate()
	# Cliente: sin autoridad, recibe completo y luego incremental.
	GameManager.start_match(MatchTypes.GameMode.REPLAY, 606)
	replicator.reset()
	replicator.apply_snapshot(full)
	replicator.apply_snapshot(partial)
	var client_state: PlayerState = GameManager.get_player_state(0)
	assert_eq(str(client_state.grid.to_dict()), expected_grid, "la cuadrícula sobrevive al snapshot incremental")
	assert_eq(client_state.shop.offer, expected_offer, "la tienda sobrevive al snapshot incremental")
