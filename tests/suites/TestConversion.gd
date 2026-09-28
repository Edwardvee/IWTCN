extends TestSuite
## Fase 11: Church Lv3 + Priest + 5 % + max_hp ≤ 600 = conversión.
## Para probar la conversión sin depender del 5 %, algunos tests fijan
## conversion_chance = 1.0 y lo restauran al terminar.

const STEP: float = 1.0 / 60.0

var processor: CommandProcessor = null
var grid0: GridManager = null
var lane: LaneManager = null
var church: StructureData = null
var soldier: UnitData = null
var priest: UnitData = null
var tank: UnitData = null


func before_each() -> void:
	if processor == null:
		processor = CommandProcessor.new()
		lane = LaneManager.new()
		grid0 = GridManager.new()
		grid0.player_id = 0
		for node: Node in [processor, lane, grid0]:
			get_root().add_child(node)
		grid0.lane = lane
		processor.register_grid(grid0)
		processor.register_lane(lane)
		church = GameManager.database.get_structure(&"church")
		soldier = GameManager.database.get_unit(&"soldier")
		priest = GameManager.database.get_unit(&"priest")
		tank = GameManager.database.get_unit(&"tank")
	GameManager.register_command_processor(processor)
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 1111)
	EconomyManager.add_gold(0, 1000)


func after_all() -> void:
	GameManager.register_command_processor(null)
	lane.clear_units()
	for node: Node in [processor, lane, grid0]:
		node.queue_free()


func _build_churches(count: int) -> void:
	for _index: int in count:
		var slot_index: int = grid0.get_state().find_first_free_slot_in_plot(4)
		GameManager.submit_command(BuildCommand.new(0, &"card_church", slot_index, GameCommand.Source.DEBUG))


func _run(seconds: float) -> void:
	for _step: int in roundi(seconds / STEP):
		lane.simulate_step(STEP)


## Priest del player 0 en y=1600 y un enemigo a 150 px (dentro de su rango 220).
func _setup_duel(enemy_data: UnitData) -> Array[UnitBase]:
	var healer: UnitBase = lane.spawn_unit(priest, 0, Vector2(540.0, 1600.0))
	var enemy: UnitBase = lane.spawn_unit(enemy_data, 1, Vector2(540.0, 1450.0))
	return [healer, enemy]


func test_church_level_3_enables_conversion() -> void:
	_build_churches(2)
	assert_true(MindConversion.get_active_source(0, priest) == null, "Church Lv2: sin conversión")
	_build_churches(1)
	assert_true(MindConversion.get_active_source(0, priest) == church, "Church Lv3: conversión activa")
	assert_true(MindConversion.get_active_source(1, priest) == null, "el rival no la tiene")


func test_conversion_on_same_instance() -> void:
	church.conversion_chance = 1.0
	_build_churches(3)
	var units: Array[UnitBase] = _setup_duel(soldier)
	var enemy: UnitBase = units[1]
	var instance_id: int = enemy.get_instance_id()
	var unit_id: int = enemy.unit_id
	var events: Array[int] = []
	var listener: Callable = func(_unidad: CharacterBody2D, anterior: int, nuevo: int) -> void:
		events.append(anterior)
		events.append(nuevo)
	EventBus.unidad_convertida.connect(listener)
	_run(0.1)
	EventBus.unidad_convertida.disconnect(listener)
	church.conversion_chance = 0.05
	assert_eq(enemy.team, 0, "ahora es aliado")
	assert_eq(enemy.get_instance_id(), instance_id, "misma instancia, sin duplicar")
	assert_eq(enemy.unit_id, unit_id, "mismo id lógico")
	assert_true(lane.get_unit(unit_id) == enemy, "sigue registrado en el LaneManager")
	assert_eq(enemy.collision_layer, 2, "capa de colisión del team 0")
	assert_eq(enemy.get_forward_direction(), Vector2(0, -1), "dirección aliada")
	assert_eq(enemy.lane_end_y, lane.get_lane_end_y(0), "final de carril aliado")
	assert_eq(events, [1, 0] as Array[int], "unidad_convertida(1 → 0) una vez")
	assert_eq(lane.get_alive_count(1), 0, "el rival pierde la unidad")
	assert_eq(lane.get_alive_count(0), 2, "el jugador la gana")


func test_converted_unit_fights_former_allies() -> void:
	church.conversion_chance = 1.0
	_build_churches(3)
	var units: Array[UnitBase] = _setup_duel(soldier)
	_run(0.1)
	church.conversion_chance = 0.05
	var converted: UnitBase = units[1]
	var former_ally: UnitBase = lane.spawn_unit(soldier, 1, Vector2(540.0, converted.global_position.y - 60.0))
	_run(0.1)
	assert_eq(converted.target_id, former_ally.unit_id, "ataca a su antiguo bando")
	assert_false(former_ally.get_target() == units[0], "el rival no sigue apuntando a quien no debe")


func test_converted_unit_moves_toward_enemy_castle() -> void:
	church.conversion_chance = 1.0
	_build_churches(3)
	var units: Array[UnitBase] = _setup_duel(soldier)
	_run(0.1)
	church.conversion_chance = 0.05
	var converted: UnitBase = units[1]
	var y_before: float = converted.global_position.y
	units[0].receive_damage(9999.0, 0)
	_run(1.0)
	assert_true(converted.global_position.y < y_before, "ahora avanza hacia arriba (castillo rival)")


func test_tank_is_never_converted() -> void:
	church.conversion_chance = 1.0
	_build_churches(3)
	var units: Array[UnitBase] = _setup_duel(tank)
	_run(0.5)
	church.conversion_chance = 0.05
	assert_eq(units[1].team, 1, "max_hp 850 > 600: inmune")


func test_no_conversion_below_level_3() -> void:
	church.conversion_chance = 1.0
	_build_churches(2)
	var units: Array[UnitBase] = _setup_duel(soldier)
	_run(0.5)
	church.conversion_chance = 0.05
	assert_eq(units[1].team, 1, "Church Lv2 no convierte")


func test_non_priest_never_converts() -> void:
	church.conversion_chance = 1.0
	_build_churches(3)
	lane.spawn_unit(soldier, 0, Vector2(540.0, 1600.0))
	var enemy: UnitBase = lane.spawn_unit(soldier, 1, Vector2(540.0, 1450.0))
	_run(0.3)
	church.conversion_chance = 0.05
	assert_eq(enemy.team, 1, "solo el Priest convierte")


func test_conversion_attempt_cooldown() -> void:
	_build_churches(3)
	church.conversion_chance = 0.0
	var units: Array[UnitBase] = _setup_duel(soldier)
	_run(0.1)
	assert_true(units[0].conversion_cooldown_left > 2.0, "tras un intento espera ~2.5 s")
	church.conversion_chance = 0.05


func test_five_percent_rate() -> void:
	var rng: RandomNumberGenerator = MindConversion.get_rng()
	var successes: int = 0
	for _roll: int in 20000:
		if MindConversion.roll(rng, 0.05):
			successes += 1
	var rate: float = float(successes) / 20000.0
	assert_true(rate > 0.04 and rate < 0.06, "≈5 %% (obtenido %.3f)" % rate)


func test_conversion_is_deterministic() -> void:
	var first: String = _long_priest_battle()
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 1111)
	EconomyManager.add_gold(0, 1000)
	var second: String = _long_priest_battle()
	assert_eq(first, second, "misma semilla → mismas conversiones")


func _long_priest_battle() -> String:
	_build_churches(3)
	church.conversion_chance = 0.5
	lane.spawn_group_at(priest, 0, 3, Vector2(540.0, 1700.0))
	lane.spawn_group_at(soldier, 1, 4, Vector2(540.0, 1300.0))
	_run(6.0)
	church.conversion_chance = 0.05
	return str(lane.to_dict())
