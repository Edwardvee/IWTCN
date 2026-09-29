extends TestSuite
## Fase 10: buffs globales afectan de verdad a unidades y producción.

const STEP: float = 1.0 / 60.0

var processor: CommandProcessor = null
var draft: DraftManager = null
var grid0: GridManager = null
var lane: LaneManager = null
var soldier: UnitData = null
var tank: UnitData = null


func before_each() -> void:
	if processor == null:
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
		soldier = GameManager.database.get_unit(&"soldier")
		tank = GameManager.database.get_unit(&"tank")
	GameManager.register_command_processor(processor)
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 1010)
	EconomyManager.add_gold(0, 1000)


func after_all() -> void:
	GameManager.register_command_processor(null)
	lane.clear_units()
	for node: Node in [processor, draft, lane, grid0]:
		node.queue_free()


func _buff(buff_id: StringName, player_id: int = 0) -> void:
	BuffSystem.apply_buff(player_id, GameManager.database.get_buff(buff_id))
	lane.refresh_team_stats(player_id)


func _spawn(data: UnitData, team: int = 0) -> UnitBase:
	return lane.spawn_unit(data, team, Vector2(540.0, 2000.0 if team == 0 else 1200.0))


func test_speed_buff_affects_existing_and_new_units() -> void:
	var existing: UnitBase = _spawn(soldier)
	_buff(&"buff_move_speed")
	assert_true(is_equal_approx(existing.move_speed, 138.0), "existente: 120 × 1.15")
	assert_true(is_equal_approx(_spawn(soldier).move_speed, 138.0), "nueva: 120 × 1.15")


func test_buffs_stack() -> void:
	_buff(&"buff_move_speed")
	_buff(&"buff_move_speed")
	assert_true(is_equal_approx(_spawn(soldier).move_speed, 156.0), "dos buffs: 120 × 1.30")


func test_hp_buff_keeps_health_ratio() -> void:
	var existing: UnitBase = _spawn(soldier)
	existing.receive_damage(125.0, 0)
	_buff(&"buff_max_hp")
	assert_true(is_equal_approx(existing.max_hp, 275.0), "250 × 1.10")
	assert_true(is_equal_approx(existing.current_hp, 137.5), "sigue al 50 %")
	assert_true(is_equal_approx(_spawn(soldier).current_hp, 275.0), "las nuevas nacen con vida llena")


func test_armor_buff_adds_mitigation() -> void:
	_buff(&"buff_armor")
	var tank_unit: UnitBase = _spawn(tank)
	assert_true(is_equal_approx(tank_unit.damage_mitigation, 0.3), "tank 0.2 + 0.1")
	assert_true(is_equal_approx(tank_unit.calculate_damage_taken(100.0), 70.0), "recibe 70 de 100")
	assert_true(is_equal_approx(_spawn(soldier).damage_mitigation, 0.1), "soldier 0 + 0.1")


func test_mitigation_is_capped() -> void:
	for _i: int in 12:
		_buff(&"buff_armor")
	assert_true(is_equal_approx(_spawn(tank).damage_mitigation, 0.9), "máximo 90 %")


func test_buffs_are_per_player() -> void:
	_buff(&"buff_move_speed")
	assert_eq(_spawn(soldier, 1).move_speed, 120.0, "el rival no se beneficia")


func test_barracks_bonus_and_buff_combine() -> void:
	GameManager.submit_command(BuildCommand.new(0, &"card_soldier_barracks", 16, GameCommand.Source.DEBUG))
	GameManager.submit_command(BuildCommand.new(0, &"card_soldier_barracks", 17, GameCommand.Source.DEBUG))
	_buff(&"buff_max_hp")
	assert_true(is_equal_approx(_spawn(soldier).max_hp, 286.0), "(250 + 10) × 1.10")


func test_production_buff_speeds_up_barracks() -> void:
	GameManager.submit_command(BuildCommand.new(0, &"card_soldier_barracks", 16, GameCommand.Source.DEBUG))
	_buff(&"buff_production")
	var barracks: StructureBase = grid0.get_structure_at(16)
	assert_true(is_equal_approx(barracks.get_production_interval(), 6.5), "8 - 1.5")
	for _step: int in roundi(6.6 / STEP):
		grid0.simulate_step(STEP)
	assert_eq(lane.get_alive_count(0), 2, "produce a los 6.5 s")


func test_production_interval_has_minimum() -> void:
	for _i: int in 10:
		_buff(&"buff_production")
	assert_eq(BuffSystem.get_production_interval(0, 8.0), 1.0, "nunca por debajo de 1 s")


func test_production_buff_does_not_affect_farms() -> void:
	GameManager.submit_command(BuildCommand.new(0, &"card_farm", 16, GameCommand.Source.DEBUG))
	_buff(&"buff_production")
	assert_eq(grid0.get_structure_at(16).get_production_interval(), 8.0, "la granja sigue en 8 s")


func test_tower_fire_rate_buff_stacks_and_is_per_player() -> void:
	assert_eq(BuffSystem.get_tower_fire_rate_multiplier(0), 1.0, "sin mejoras: cadencia normal")
	_buff(&"buff_tower_fire_rate")
	assert_true(is_equal_approx(BuffSystem.get_tower_fire_rate_multiplier(0), 1.1), "una mejora: +10%")
	_buff(&"buff_tower_fire_rate")
	assert_true(is_equal_approx(BuffSystem.get_tower_fire_rate_multiplier(0), 1.2), "dos mejoras: +20% (se suma)")
	assert_eq(BuffSystem.get_tower_fire_rate_multiplier(1), 1.0, "el rival no se beneficia")


func test_tower_fire_rate_buff_shortens_cooldown() -> void:
	GameManager.submit_command(BuildCommand.new(0, &"card_tower", 16, GameCommand.Source.DEBUG))
	var tower: TowerStructure = grid0.get_structure_at(16) as TowerStructure
	assert_true(tower != null, "torre construida")
	if tower == null:
		return
	_spawn(soldier, 1)
	lane.get_alive_units()[0].global_position = tower.global_position + Vector2(0.0, -300.0)
	tower.simulate(0.0)
	assert_true(is_equal_approx(tower.cooldown_left, 1.0), "Lv1 sin mejora: 1.0 s (%.3f)" % tower.cooldown_left)
	tower.cooldown_left = 0.0
	_buff(&"buff_tower_fire_rate")
	tower.simulate(0.0)
	assert_true(is_equal_approx(tower.cooldown_left, 1.0 / 1.1), "con una mejora: 1.0 / 1.1 (%.3f)" % tower.cooldown_left)


func test_tower_buff_card_needs_a_tower() -> void:
	var card: CardData = GameManager.database.get_card(&"card_buff_tower_fire_rate")
	assert_true(card != null, "la carta existe")
	if card == null:
		return
	assert_false(draft.is_card_available(0, card), "sin torre no se ofrece")
	GameManager.submit_command(BuildCommand.new(0, &"card_tower", 16, GameCommand.Source.DEBUG))
	assert_true(draft.is_card_available(0, card), "con una torre sí")


func test_play_buff_card_anywhere() -> void:
	var existing: UnitBase = _spawn(soldier)
	draft.force_offer(0, [&"card_buff_move_speed", &"card_farm", &"card_tower"] as Array[StringName])
	var gold_before: int = EconomyManager.get_gold(0)
	var command: PlayCardCommand = PlayCardCommand.new(0, 0, &"card_buff_move_speed", -1, Vector2(10.0, 10.0))
	assert_true(GameManager.submit_command(command), "carta de mejora aceptada en cualquier posición")
	assert_eq(EconomyManager.get_gold(0), gold_before - 80, "cobra 80")
	assert_eq(GameManager.get_player_state(0).buffs, [&"buff_move_speed"] as Array[StringName], "buff registrado")
	assert_true(is_equal_approx(existing.move_speed, 138.0), "afecta a las unidades ya desplegadas")


func test_restart_clears_buffs() -> void:
	_buff(&"buff_move_speed")
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 1011)
	assert_eq(GameManager.get_player_state(0).buffs.size(), 0, "sin buffs en partida nueva")
	var players: Array = GameManager.match_state.to_dict()["players"]
	assert_true((players[0] as Dictionary).has("buffs"), "buffs en el snapshot")
