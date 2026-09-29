extends TestSuite
## Razas (humanos, goblins, elfos): los efectos salen de data/races/*.tres, así
## que estas pruebas comparan contra los valores de cada archivo en vez de números
## fijos. También la cuenta atrás de inicio de partida.

const STEP: float = 1.0 / 60.0

var processor: CommandProcessor = null
var draft: DraftManager = null
var lane: LaneManager = null
var grid0: GridManager = null
var grid1: GridManager = null
var replicator: StateReplicator = null
var database: GameDatabase = null


func before_each() -> void:
	if processor == null:
		database = GameManager.database
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
	GameManager.register_command_processor(processor)
	_start(&"human", &"human")


func after_all() -> void:
	GameManager.match_races = []
	GameManager.register_command_processor(null)
	lane.clear_units()
	for node: Node in [processor, draft, lane, grid0, grid1, replicator]:
		node.queue_free()


func _start(bottom: StringName, top: StringName) -> void:
	GameManager.match_races = [bottom, top]
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 314)


func _spawn(unit_id: StringName, team: int) -> UnitBase:
	return lane.spawn_unit(database.get_unit(unit_id), team, Vector2(540.0, 2000.0 if team == 0 else 1200.0))


func test_three_races_exist_and_validate() -> void:
	for race_id: StringName in [&"human", &"goblin", &"elf"]:
		assert_true(database.get_race(race_id) != null and database.get_race(race_id).id == race_id, "existe la raza %s" % race_id)
	assert_eq(database.races.size(), 3, "tres razas")
	assert_true(database.get_validation_errors().is_empty(), "los datos validan: %s" % str(database.get_validation_errors()))
	assert_eq(database.get_race(&"desconocida").id, &"human", "una raza desconocida cae en humanos")


func test_human_is_the_neutral_baseline() -> void:
	var human: RaceData = database.get_race(&"human")
	for value: float in [human.unit_card_cost_multiplier, human.structure_card_cost_multiplier, human.buff_card_cost_multiplier, human.income_multiplier, human.hp_multiplier, human.damage_multiplier, human.attack_speed_multiplier, human.move_speed_multiplier, human.attack_range_multiplier, human.production_interval_multiplier, human.castle_hp_multiplier]:
		assert_eq(value, 1.0, "los humanos no modifican nada")
	assert_true(human.unit_overrides.is_empty(), "sin ajustes por unidad")


func test_race_traits_follow_the_design() -> void:
	var goblin: RaceData = database.get_race(&"goblin")
	var elf: RaceData = database.get_race(&"elf")
	assert_true(goblin.hp_multiplier < 1.0, "goblins: menos vida")
	assert_true(goblin.attack_speed_multiplier > 1.0, "goblins: atacan más rápido")
	assert_true(goblin.unit_card_cost_multiplier < 1.0, "goblins: unidades más baratas")
	assert_true(elf.unit_card_cost_multiplier > 1.0 and elf.structure_card_cost_multiplier > 1.0, "elfos: más caros")


func test_unit_stats_follow_the_race_file() -> void:
	var soldier: UnitData = database.get_unit(&"soldier")
	_start(&"goblin", &"elf")
	var goblin: RaceData = database.get_race(&"goblin")
	var elf: RaceData = database.get_race(&"elf")
	var goblin_soldier: UnitBase = _spawn(&"soldier", 0)
	assert_true(is_equal_approx(goblin_soldier.max_hp, soldier.max_hp * goblin.hp_multiplier), "vida goblin (%.1f)" % goblin_soldier.max_hp)
	assert_true(is_equal_approx(goblin_soldier.attack_cooldown, soldier.attack_cooldown / goblin.attack_speed_multiplier), "ataca %.0f %% más rápido" % ((goblin.attack_speed_multiplier - 1.0) * 100.0))
	assert_true(is_equal_approx(goblin_soldier.move_speed, soldier.move_speed * goblin.move_speed_multiplier), "velocidad goblin")
	var elf_soldier: UnitBase = _spawn(&"soldier", 1)
	assert_true(is_equal_approx(elf_soldier.max_hp, soldier.max_hp * elf.hp_multiplier), "vida élfica")
	assert_true(is_equal_approx(elf_soldier.damage, soldier.damage * elf.damage_multiplier), "daño élfico")
	var human_check: UnitBase = null
	_start(&"human", &"human")
	human_check = _spawn(&"soldier", 0)
	assert_eq(human_check.max_hp, soldier.max_hp, "los humanos conservan la vida base")


func test_unit_override_multiplies_with_the_general_multiplier() -> void:
	_start(&"elf", &"human")
	var elf: RaceData = database.get_race(&"elf")
	var archer_data: UnitData = database.get_unit(&"archer")
	var archer_override: RaceUnitOverride = elf.get_unit_override(&"archer")
	var range_factor: float = elf.attack_range_multiplier * (archer_override.attack_range_multiplier if archer_override != null else 1.0)
	var archer: UnitBase = _spawn(&"archer", 0)
	assert_true(is_equal_approx(archer.attack_range, archer_data.attack_range * range_factor), "alcance = general × de la unidad (%.1f)" % archer.attack_range)


func test_card_costs_follow_the_race() -> void:
	var soldiers: CardData = database.get_card(&"card_soldiers")
	var farm: CardData = database.get_card(&"card_farm")
	var buff: CardData = database.get_card(&"card_buff_armor")
	_start(&"goblin", &"elf")
	var goblin: RaceData = database.get_race(&"goblin")
	var elf: RaceData = database.get_race(&"elf")
	assert_eq(EconomyManager.get_card_cost(0, soldiers), roundi(soldiers.cost * goblin.unit_card_cost_multiplier), "unidades goblin más baratas")
	assert_true(EconomyManager.get_card_cost(0, soldiers) < EconomyManager.get_card_cost(1, soldiers), "el goblin paga menos que el elfo por las mismas tropas")
	assert_eq(EconomyManager.get_card_cost(1, farm), roundi(farm.cost * elf.structure_card_cost_multiplier), "estructuras élficas más caras")
	assert_eq(EconomyManager.get_card_cost(1, buff), roundi(buff.cost * elf.buff_card_cost_multiplier), "mejoras élficas más caras")
	assert_eq(EconomyManager.get_card_cost(0, farm), roundi(farm.cost * goblin.structure_card_cost_multiplier), "las estructuras goblin siguen a su multiplicador")


func test_production_and_income_multipliers() -> void:
	var goblin: RaceData = database.get_race(&"goblin")
	var original_interval: float = goblin.production_interval_multiplier
	var original_income: float = goblin.income_multiplier
	goblin.production_interval_multiplier = 0.5
	goblin.income_multiplier = 2.0
	_start(&"goblin", &"human")
	EconomyManager.add_gold(0, 500)
	GameManager.submit_command(BuildCommand.new(0, &"card_soldier_barracks", 16, GameCommand.Source.DEBUG))
	var barracks: SpawnerStructure = grid0.get_structure_at(16) as SpawnerStructure
	var base_interval: float = database.get_structure(&"soldier_barracks").get_spawn_interval(1)
	assert_true(barracks != null and is_equal_approx(barracks.get_production_interval(), base_interval * 0.5), "la raza acorta los ciclos de producción")
	var before: int = EconomyManager.get_gold(0)
	EconomyManager.add_income(0, 10)
	assert_eq(EconomyManager.get_gold(0) - before, 20, "el multiplicador de ingresos de la raza")
	goblin.production_interval_multiplier = original_interval
	goblin.income_multiplier = original_income


func test_race_art_is_used_for_units_and_structures() -> void:
	_start(&"goblin", &"elf")
	var goblin: RaceData = database.get_race(&"goblin")
	var elf: RaceData = database.get_race(&"elf")
	var human_frames: SpriteFrames = database.get_unit(&"soldier").sprite_frames
	assert_true(goblin.get_unit_frames(database.get_unit(&"soldier")) != human_frames, "los goblins tienen sprites propios")
	assert_true(elf.get_unit_frames(database.get_unit(&"archer")) != database.get_unit(&"archer").sprite_frames, "los elfos también")
	assert_true(goblin.get_structure_texture(database.get_structure(&"farm")) != database.get_structure(&"farm").texture, "estructuras goblin distintas")
	assert_true(goblin.castle_texture != null and elf.castle_texture != null and goblin.castle_texture != elf.castle_texture, "cada raza tiene su castillo")
	var goblin_unit: UnitBase = _spawn(&"soldier", 0)
	var sprite: AnimatedSprite2D = goblin_unit.get_node_or_null("@AnimatedSprite2D@%d" % 0) as AnimatedSprite2D
	var found: AnimatedSprite2D = null
	for child: Node in goblin_unit.get_children():
		if child is AnimatedSprite2D:
			found = child as AnimatedSprite2D
	assert_true(sprite == null or found != null, "la unidad tiene sprite animado")
	assert_true(found != null and found.sprite_frames == goblin.get_unit_frames(database.get_unit(&"soldier")), "el sprite es el de su raza")
	assert_eq(found.scale, goblin.get_unit_sprite_scale(database.get_unit(&"soldier")), "y su escala")
	EconomyManager.add_gold(0, 500)
	GameManager.submit_command(BuildCommand.new(0, &"card_farm", 16, GameCommand.Source.DEBUG))
	var farm: StructureBase = grid0.get_structure_at(16)
	assert_true(farm != null and farm._art_texture == goblin.get_structure_texture(database.get_structure(&"farm")), "la granja usa el arte goblin")


func test_race_travels_in_snapshots_and_replays() -> void:
	_start(&"elf", &"goblin")
	var snapshot: Dictionary = replicator.build_snapshot()
	var players: Array = snapshot["match"]["players"]
	assert_eq(players[0]["race"], &"elf", "el snapshot lleva la raza del asiento 0")
	assert_eq(players[1]["race"], &"goblin", "y la del asiento 1")
	GameManager.match_races = []
	GameManager.start_match(MatchTypes.GameMode.REPLAY, 1)
	replicator.reset()
	replicator.apply_snapshot(snapshot)
	assert_eq(GameManager.get_player_state(0).race_id, &"elf", "el cliente adopta la raza")
	assert_eq(GameManager.get_player_state(1).race_id, &"goblin", "también la del rival")
	var replay: ReplayData = ReplayData.new({"races": ["goblin", "elf"]})
	assert_eq(replay.get_races(), [&"goblin", &"elf"] as Array[StringName], "la repetición guarda las razas")
	assert_eq(ReplayData.new().get_races(), [&"human", &"human"] as Array[StringName], "sin razas guardadas, humanos")


func test_race_names_are_translated() -> void:
	for race: RaceData in database.races:
		assert_true(TranslationTables.EN.has(race.display_name), "nombre de raza '%s' en inglés" % race.display_name)
		assert_true(TranslationTables.EN.has(race.description), "descripción de '%s' en inglés" % race.id)
		for card_name: Variant in race.card_names.values():
			assert_true(TranslationTables.EN.has(str(card_name)) and TranslationTables.ES.has(str(card_name)), "carta '%s' traducida a ES y EN" % str(card_name))


# --- Cuenta atrás de inicio ------------------------------------------------------------

func test_countdown_freezes_the_match_until_begin_play() -> void:
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 314, true)
	assert_true(GameManager.is_in_countdown(), "empieza en cuenta atrás")
	assert_false(GameManager.is_match_running(), "la partida aún no corre")
	var gold_before: int = EconomyManager.get_gold(0)
	EconomyManager.simulate_step(10.0)
	assert_eq(EconomyManager.get_gold(0), gold_before, "no hay ingresos durante la cuenta atrás")
	assert_false(GameManager.submit_command(RerollShopCommand.new(0)), "ni se puede jugar")
	assert_true(GameManager.get_player_state(0).shop.offer.size() > 0, "pero las tiendas ya están listas")
	var started: Array[bool] = [false]
	var listener: Callable = func() -> void: started[0] = true
	EventBus.partida_comenzada.connect(listener)
	GameManager.begin_play()
	EventBus.partida_comenzada.disconnect(listener)
	assert_true(started[0], "se avisa del comienzo")
	assert_true(GameManager.is_match_running(), "ahora sí corre")
	EconomyManager.simulate_step(3.0)
	assert_true(EconomyManager.get_gold(0) > gold_before, "y llegan los ingresos")
	GameManager.begin_play()
	assert_true(GameManager.is_match_running(), "begin_play repetido no rompe nada")


func test_match_intro_counts_then_shouts_then_finishes() -> void:
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 314, true)
	var intro: MatchIntro = MatchIntro.new()
	var finished: Array[bool] = [false]
	intro.finished.connect(func() -> void: finished[0] = true)
	get_root().add_child(intro)
	assert_true(MatchIntro.COUNT_STEP * 3.0 + MatchIntro.SHOUT_TIME < 5.0, "dura menos de 5 s")
	assert_eq(MatchIntro.SHOUT_TEXT, "I WANT THAT\nCASTLE NOW!", "el grito final")
	intro._finish()
	assert_true(finished[0], "termina y avisa")
	GameManager.begin_play()
