extends TestSuite
## Escalado por nivel con los DATOS REALES (el resto de suites usa los valores
## fijados en TestBalance): tope de tropas por granjas, precio de cada nivel,
## velocidad de ataque de las unidades y cantidad de unidades por carta.

const STEP: float = 1.0 / 60.0

var real_database: GameDatabase = null
var processor: CommandProcessor = null
var draft: DraftManager = null
var lane: LaneManager = null
var grid0: GridManager = null
var next_slot: int = 0


func before_each() -> void:
	# Estas pruebas usan los datos reales de data/, no los valores fijados.
	TestBalance.restore_real()
	if real_database == null:
		real_database = GameManager.database
		processor = CommandProcessor.new()
		draft = DraftManager.new()
		lane = LaneManager.new()
		grid0 = GridManager.new()
		grid0.player_id = 0
		grid0.position = Vector2(30.0, 2460.0)
		for node: Node in [processor, draft, lane, grid0]:
			get_root().add_child(node)
		grid0.lane = lane
		processor.register_grid(grid0)
		processor.register_lane(lane)
		processor.register_draft(draft)
	GameManager.register_command_processor(processor)
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 808)
	next_slot = 0


func after_all() -> void:
	TestBalance.apply()
	GameManager.register_command_processor(null)
	lane.clear_units()
	for node: Node in [processor, draft, lane, grid0]:
		node.queue_free()


## Coloca `count` copias de una estructura en el estado del jugador 0 (sin oro ni nodos).
func _own(structure_id: StringName, count: int) -> void:
	for _copy: int in count:
		GameManager.get_player_state(0).grid.place_structure(next_slot, structure_id, 100 + next_slot, 0)
		next_slot += 1


func test_real_rules_are_valid() -> void:
	assert_true(real_database.get_validation_errors().is_empty(), "los datos reales validan: %s" % str(real_database.get_validation_errors()))


func test_unit_cap_grows_with_farm_level() -> void:
	var rules: GameRules = real_database.rules
	var expected: Array[int] = [3, 8, 12, 24, 36, 60]
	for level: int in expected.size():
		assert_eq(rules.get_unit_cap_for_level(level), expected[level], "tope con %d granjas" % level)
	assert_eq(rules.get_unit_cap_for_level(9), 60, "más granjas que niveles: el último tope")
	assert_eq(rules.unit_cap_override, 0, "los datos reales no fuerzan un tope fijo")


func test_lane_cap_follows_owned_farms_and_blocks_spawns() -> void:
	var soldier: UnitData = real_database.get_unit(&"soldier")
	assert_eq(lane.get_unit_cap(0), 3, "sin granjas: 3")
	for _index: int in 3:
		assert_true(lane.spawn_unit(soldier, 0, Vector2(540.0, 2000.0)) != null, "cabe hasta el tope")
	assert_true(lane.spawn_unit(soldier, 0, Vector2(540.0, 2000.0)) == null, "con 3 tropas no aparece otra")
	_own(&"farm", 1)
	assert_eq(lane.get_unit_cap(0), 8, "1 granja: 8")
	assert_true(lane.spawn_unit(soldier, 0, Vector2(540.0, 2000.0)) != null, "subir la granja libera hueco")
	_own(&"farm", 4)
	assert_eq(lane.get_unit_cap(0), 60, "5 granjas: 60")
	assert_eq(lane.get_unit_cap(1), 3, "el rival tiene su propio tope")


func test_unit_card_rejected_over_the_cap() -> void:
	EconomyManager.add_gold(0, 1000)
	draft.force_offer(0, [&"card_soldiers", &"card_farm", &"card_tower"] as Array[StringName])
	lane.spawn_group_at(real_database.get_unit(&"soldier"), 0, 2, Vector2(540.0, 2000.0))
	# 2 vivas + 3 de la carta (nivel 0) superan el tope de 3.
	var rejected_with: PackedStringArray = PackedStringArray()
	var listener: Callable = func(_player_id: int, _type: StringName, reason: String) -> void: rejected_with.append(reason)
	EventBus.comando_rechazado.connect(listener)
	var played: bool = GameManager.submit_command(PlayCardCommand.new(0, 0, &"card_soldiers", -1, Vector2(540.0, 2000.0)))
	EventBus.comando_rechazado.disconnect(listener)
	assert_false(played, "la carta no cabe")
	assert_true(rejected_with.size() == 1 and rejected_with[0].begins_with("Límite de tropas alcanzado"), "el motivo habla del límite (%s)" % str(rejected_with))
	assert_eq(EconomyManager.get_gold(0), 1000 + GameManager.get_rules().starting_gold, "no se cobra")


func test_each_level_costs_much_more_from_level_three() -> void:
	var rules: GameRules = real_database.rules
	var farm_costs: Array[int] = []
	var barracks_costs: Array[int] = []
	for owned: int in 5:
		farm_costs.append(rules.get_scaled_structure_cost(real_database.get_card(&"card_farm").cost, owned))
		barracks_costs.append(rules.get_scaled_structure_cost(real_database.get_card(&"card_soldier_barracks").cost, owned))
	assert_eq(farm_costs, [50, 63, 125, 200, 300] as Array[int], "Farm: coste de cada nivel")
	assert_eq(barracks_costs, [60, 75, 150, 240, 360] as Array[int], "Cuartel: coste de cada nivel")
	var step_one: int = farm_costs[1] - farm_costs[0]
	var step_two: int = farm_costs[2] - farm_costs[1]
	assert_true(step_two >= 4 * step_one, "pasar del nivel 2 al 3 cuesta al menos 4 veces más que del 1 al 2 (%d vs %d)" % [step_two, step_one])
	assert_true(farm_costs[4] > farm_costs[3] and farm_costs[3] > farm_costs[2], "cada nivel siguiente cuesta más")


func test_archer_attack_speed_scales_with_barracks_level() -> void:
	var archer: UnitData = real_database.get_unit(&"archer")
	assert_eq(archer.attack_cooldown, 1.0, "el arquero base ataca 1 vez por segundo")
	var expected_rates: Array[float] = [0.9, 1.0, 1.2, 1.8, 1.8, 2.0]
	for level: int in expected_rates.size():
		if level > 0:
			_own(&"archer_barracks", 1)
		var unit: UnitBase = lane.spawn_unit(archer, 0, Vector2(540.0, 2000.0 + level))
		if unit == null:
			lane.clear_units()
			unit = lane.spawn_unit(archer, 0, Vector2(540.0, 2000.0))
		assert_true(is_equal_approx(1.0 / unit.attack_cooldown, expected_rates[level]), "nivel %d: %.1f ataques/s (%.3f)" % [level, expected_rates[level], 1.0 / unit.attack_cooldown])
		lane.clear_units()


func test_attack_speed_applies_to_card_units_by_their_barracks_and_skips_tank() -> void:
	_own(&"soldier_barracks", 5)
	var soldier: UnitBase = lane.spawn_unit(real_database.get_unit(&"soldier"), 0, Vector2(540.0, 2000.0))
	assert_true(is_equal_approx(soldier.attack_cooldown, real_database.get_unit(&"soldier").attack_cooldown / 2.0), "soldados con cuartel nivel 5: el doble de rápido")
	var tank: UnitBase = lane.spawn_unit(real_database.get_unit(&"tank"), 0, Vector2(540.0, 2000.0))
	assert_eq(tank.attack_cooldown, real_database.get_unit(&"tank").attack_cooldown, "el Tank no tiene cuartel propio: sin escalado")


func test_card_unit_count_depends_on_barracks_level() -> void:
	var soldiers: CardData = real_database.get_card(&"card_soldiers")
	var archers: CardData = real_database.get_card(&"card_archers")
	var expected_soldiers: Array[int] = [3, 3, 3, 4, 4, 5]
	var expected_archers: Array[int] = [2, 2, 2, 3, 3, 4]
	for level: int in 6:
		if level > 0:
			_own(&"soldier_barracks", 1)
			_own(&"archer_barracks", 1)
		assert_eq(soldiers.get_unit_count_for(0), expected_soldiers[level], "Soldiers con cuartel nivel %d" % level)
		assert_eq(archers.get_unit_count_for(0), expected_archers[level], "Archers con cuartel nivel %d" % level)
	assert_eq(real_database.get_card(&"card_tank").get_unit_count_for(0), 1, "el Tank siempre es 1")


func test_playing_a_unit_card_deploys_the_scaled_count() -> void:
	_own(&"farm", 3)
	_own(&"soldier_barracks", 3)
	EconomyManager.add_gold(0, 1000)
	draft.force_offer(0, [&"card_soldiers", &"card_farm", &"card_tower"] as Array[StringName])
	assert_true(GameManager.submit_command(PlayCardCommand.new(0, 0, &"card_soldiers", -1, Vector2(540.0, 2000.0))), "se juega la carta")
	assert_eq(lane.get_alive_count(0), 4, "con cuartel nivel 3 salen 4 soldados")
