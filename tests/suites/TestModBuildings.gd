extends TestSuite
## Edificios modificadores de partida: catálogo, efectos, selector, iconos, reloj y código de sala.

const STEP: float = 1.0 / 60.0

var lane: LaneManager = null


func before_each() -> void:
	GameManager.match_mods = []
	NetworkManager.room_code = ""


func after_all() -> void:
	GameManager.match_mods = []
	GameManager.player_mod = &""
	NetworkManager.room_code = ""
	if lane != null:
		lane.clear_units()
		lane.queue_free()
		lane = null


func _start(mods: Array[StringName]) -> void:
	GameManager.match_mods = mods
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 909)


func _lane() -> LaneManager:
	if lane == null:
		lane = LaneManager.new()
		get_root().add_child(lane)
	lane.clear_units()
	return lane


# --- Catálogo ------------------------------------------------------------------

func test_catalog_has_seven_buildings_with_art_and_texts() -> void:
	assert_eq(ModBuildings.IDS.size(), 7, "siete edificios")
	for id: StringName in ModBuildings.IDS:
		assert_true(ModBuildings.is_valid(id), "%s válido" % id)
		assert_true(ModBuildings.icon(id) != null, "%s tiene dibujo" % id)
		assert_true(ModBuildings.display_name(id) != "", "%s tiene nombre" % id)
		assert_true(ModBuildings.description(id) != "", "%s tiene descripción" % id)
	assert_false(ModBuildings.is_valid(&"nada"), "un id raro no es válido")


func test_catalog_texts_are_translated() -> void:
	for id: StringName in ModBuildings.IDS:
		var entry: Dictionary = ModBuildings._DATA[id]
		assert_true(TranslationTables.EN.has(str(entry["name"])), "nombre de %s en inglés" % id)
		assert_true(TranslationTables.EN.has(str(entry["description"])), "descripción de %s en inglés" % id)


func test_roll_offers_three_distinct_valid_buildings() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for seed_value: int in range(1, 40):
		rng.seed = seed_value
		var choices: Array[StringName] = ModBuildings.roll_choices(rng)
		assert_eq(choices.size(), 3, "tres opciones (semilla %d)" % seed_value)
		var unique: Dictionary = {}
		for id: StringName in choices:
			assert_true(ModBuildings.is_valid(id), "opción válida")
			unique[id] = true
		assert_eq(unique.size(), 3, "sin repetidos (semilla %d)" % seed_value)


func test_seed_pick_is_valid_and_deterministic() -> void:
	assert_eq(ModBuildings.pick_from_seed(12345, 13), ModBuildings.pick_from_seed(12345, 13), "misma semilla, mismo edificio")
	assert_true(ModBuildings.is_valid(ModBuildings.pick_from_seed(987654, 5)), "siempre uno válido")


# --- Efectos ---------------------------------------------------------------------

func test_match_assigns_buildings_to_players() -> void:
	_start([ModBuildings.FORGE, ModBuildings.SAWMILL])
	assert_eq(GameManager.get_player_state(0).mod_building, ModBuildings.FORGE, "abajo")
	assert_eq(GameManager.get_player_state(1).mod_building, ModBuildings.SAWMILL, "arriba")
	assert_eq(GameManager.get_player_state(0).to_dict()["mod"], ModBuildings.FORGE, "viaja en el estado")
	_start([&"inventado", &""])
	assert_eq(GameManager.get_player_state(0).mod_building, &"", "un id desconocido se ignora")


func test_gold_mine_raises_base_income() -> void:
	_start([ModBuildings.GOLD_MINE, &""])
	var rules: GameRules = GameManager.get_rules()
	var before_mine: int = EconomyManager.get_gold(0)
	var before_plain: int = EconomyManager.get_gold(1)
	EconomyManager.simulate_step(rules.base_income_interval)
	var mine_gain: int = EconomyManager.get_gold(0) - before_mine
	var plain_gain: int = EconomyManager.get_gold(1) - before_plain
	assert_eq(mine_gain - plain_gain, ModBuildings.GOLD_MINE_BASE_INCOME_BONUS, "la mina suma su bonus a cada ingreso base")


func test_sawmill_discounts_structures_only() -> void:
	_start([ModBuildings.SAWMILL, &""])
	var structure_card: CardData = null
	var unit_card: CardData = null
	for card: CardData in GameManager.database.cards:
		if structure_card == null and card.card_type == CardData.CardType.STRUCTURE and card.required_race == &"":
			structure_card = card
		if unit_card == null and card.card_type == CardData.CardType.DIRECT_UNIT and card.required_race == &"":
			unit_card = card
	var plain: int = EconomyManager.get_card_cost(1, structure_card)
	assert_eq(EconomyManager.get_card_cost(0, structure_card), roundi(float(plain) * (1.0 - ModBuildings.SAWMILL_DISCOUNT)), "estructura un 5 % más barata")
	assert_eq(EconomyManager.get_card_cost(0, unit_card), EconomyManager.get_card_cost(1, unit_card), "las cartas de unidad no cambian")


func test_forge_adds_damage_to_own_troops() -> void:
	_start([ModBuildings.FORGE, &""])
	var world: LaneManager = _lane()
	var soldier: UnitData = GameManager.database.get_unit(&"soldier")
	var forged: UnitBase = world.spawn_unit(soldier, 0, Vector2(540.0, 2200.0))
	var plain: UnitBase = world.spawn_unit(soldier, 1, Vector2(540.0, 1000.0))
	assert_true(absf(forged.damage - plain.damage * (1.0 + ModBuildings.FORGE_DAMAGE_BONUS)) < 0.01, "+3 %% de daño (%.2f vs %.2f)" % [forged.damage, plain.damage])
	assert_eq(forged.max_hp, plain.max_hp, "la vida no cambia")


func test_raider_camp_cuts_rival_farm_income() -> void:
	_start([ModBuildings.RAIDER_CAMP, &""])
	var farm_data: StructureData = GameManager.database.get_structure(&"farm")
	var raided: FarmStructure = FarmStructure.new()
	raided.data = farm_data
	raided.owner_id = 1
	var safe: FarmStructure = FarmStructure.new()
	safe.data = farm_data
	safe.owner_id = 0
	assert_eq(raided.get_raided_income(), raided.get_income_per_cycle() - ModBuildings.RAIDER_FARM_PENALTY, "la granja del rival da 2 menos")
	assert_eq(safe.get_raided_income(), safe.get_income_per_cycle(), "la del dueño del campamento no cambia")
	raided.free()
	safe.free()


func test_swindler_raises_reroll_for_both_and_it_never_decays_below() -> void:
	_start([ModBuildings.SWINDLER, &""])
	var rules: GameRules = GameManager.get_rules()
	var expected: int = rules.reroll_base_cost + ModBuildings.SWINDLER_REROLL_SURCHARGE
	for player_id: int in 2:
		assert_eq(GameManager.get_player_state(player_id).shop.reroll_cost, expected, "reroll de %d más caro" % player_id)
	var draft: DraftManager = DraftManager.new()
	draft.simulate_step(rules.reroll_decay_interval * 5.0)
	for player_id: int in 2:
		assert_eq(GameManager.get_player_state(player_id).shop.reroll_cost, expected, "no baja del suelo con recargo (%d)" % player_id)
	draft.free()
	_start([&"", &""])
	assert_eq(GameManager.get_player_state(0).shop.reroll_cost, rules.reroll_base_cost, "sin estafador, el base de siempre")


func test_stonemasons_add_castle_health() -> void:
	_start([ModBuildings.STONEMASONS, &""])
	var plain: PlayerState = GameManager.get_player_state(1)
	var masons: PlayerState = GameManager.get_player_state(0)
	assert_eq(masons.castle_max_hp - plain.castle_max_hp, ModBuildings.STONEMASONS_CASTLE_HP, "+1000 de vida máxima")
	assert_eq(masons.castle_hp, masons.castle_max_hp, "y el castillo empieza lleno")


func test_necromancer_revives_a_fallen_troop_every_12_seconds() -> void:
	_start([ModBuildings.NECROMANCER, &""])
	var world: LaneManager = _lane()
	var soldier: UnitData = GameManager.database.get_unit(&"soldier")
	var fallen: UnitBase = world.spawn_unit(soldier, 0, Vector2(540.0, 2200.0))
	world.spawn_unit(soldier, 0, Vector2(500.0, 2200.0)).die()
	fallen.die()
	world.simulate_step(STEP)
	assert_eq(world.get_alive_count(0), 0, "los dos han caído")
	for _step: int in roundi(ModBuildings.NECROMANCER_INTERVAL / STEP) + 2:
		world.simulate_step(STEP)
	assert_eq(world.get_alive_count(0), 1, "vuelve una tropa (solo una por ciclo)")
	var revived: UnitBase = null
	for unit: UnitBase in world.get_alive_units():
		revived = unit
	assert_true(revived != null and revived.revived, "la resucitada está marcada")
	assert_eq(revived.modulate, ModBuildings.REVIVED_TINT, "y se ve celeste verdosa")
	assert_true((world.to_snapshot()["rv"] as PackedInt32Array).has(revived.unit_id), "el snapshot avisa a los clientes")
	for _step: int in roundi(ModBuildings.NECROMANCER_INTERVAL / STEP) + 2:
		world.simulate_step(STEP)
	assert_true(world.get_alive_count(0) >= 1, "sigue en pie o se levanta la otra")


func test_necromancer_does_nothing_without_fallen_or_for_the_rival() -> void:
	_start([ModBuildings.NECROMANCER, &""])
	var world: LaneManager = _lane()
	for _step: int in roundi(ModBuildings.NECROMANCER_INTERVAL / STEP) + 2:
		world.simulate_step(STEP)
	assert_eq(world.get_alive_count(0), 0, "sin caídos no hay nada que levantar")
	var soldier: UnitData = GameManager.database.get_unit(&"soldier")
	world.spawn_unit(soldier, 1, Vector2(540.0, 1000.0)).die()
	for _step: int in roundi(ModBuildings.NECROMANCER_INTERVAL / STEP) + 2:
		world.simulate_step(STEP)
	assert_eq(world.get_alive_count(1), 0, "el rival sin nigromante no revive")


# --- Selector --------------------------------------------------------------------

func _make_select() -> BuildingSelect:
	BuildingSelect.next_mode = RaceSelect.Mode.ONLINE_HOST
	var select: BuildingSelect = (load(BuildingSelect.SCENE_PATH) as PackedScene).instantiate() as BuildingSelect
	get_root().add_child(select)
	return select


func test_selector_offers_three_and_locks_the_marked_one() -> void:
	GameManager.player_mod = &""
	var select: BuildingSelect = _make_select()
	assert_eq(select.get_choices().size(), 3, "tres para elegir")
	select.select_index(2)
	var chosen: StringName = select.get_choices()[2]
	assert_eq(select.get_selected_id(), chosen, "se marca la tocada")
	select.lock_choice()
	assert_true(select.is_locked(), "fijado")
	assert_eq(GameManager.player_mod, chosen, "es el edificio del jugador")
	select.select_index(0)
	assert_eq(select.get_selected_id(), chosen, "ya no se puede cambiar")
	select.queue_free()


func test_selector_gives_eight_seconds() -> void:
	assert_eq(BuildingSelect.SECONDS, 8.0, "8 segundos")


# --- HUD -------------------------------------------------------------------------

func test_world_views_show_each_players_building_and_open_info_on_tap() -> void:
	_start([ModBuildings.FORGE, ModBuildings.SWINDLER])
	var own: ModBuildingView = ModBuildingView.new()
	var rival: ModBuildingView = ModBuildingView.new()
	get_root().add_child(own)
	get_root().add_child(rival)
	own.setup(0, Vector2(177.0, 2245.0))
	rival.setup(1, Vector2(903.0, 955.0))
	assert_eq(own.get_shown(), ModBuildings.FORGE, "el tuyo, junto a tu castillo")
	assert_eq(rival.get_shown(), ModBuildings.SWINDLER, "el del rival")
	assert_true(own.contains_point(Vector2(180.0, 2250.0)), "tocar el edificio")
	assert_false(own.contains_point(Vector2(540.0, 2250.0)), "tocar el carril no cuenta")
	assert_false(own.is_info_visible(), "cerrado al principio")
	own.toggle_info()
	assert_true(own.is_info_visible(), "el toque abre el cuadro")
	own.toggle_info()
	assert_false(own.is_info_visible(), "otro toque lo cierra")
	_start([&"", &""])
	own._refresh(false)
	assert_eq(own.get_shown(), &"", "sin edificio no se dibuja nada")
	assert_false(own.contains_point(Vector2(180.0, 2250.0)), "ni se puede tocar")
	own.queue_free()
	rival.queue_free()


func test_spell_panel_fades_only_near_the_pointer() -> void:
	var panel: SpellPanel = SpellPanel.new()
	get_root().add_child(panel)
	panel.set_drag_pointer(Vector2(-5000.0, -5000.0), true)
	assert_eq(panel._column.modulate.a, 1.0, "lejos: opaco")
	panel.set_drag_pointer(Vector2.ZERO, false)
	assert_eq(panel._column.modulate.a, 1.0, "sin arrastre: opaco")
	panel.queue_free()


func test_clock_shows_match_time_in_minutes_and_seconds() -> void:
	_start([&"", &""])
	var clock: MatchClock = MatchClock.new()
	get_root().add_child(clock)
	GameManager.match_state.match_time = 125.0
	clock._refresh(true)
	assert_eq(clock.text, "2:05", "125 s = 2:05")
	GameManager.match_state.match_time = 9.0
	clock._refresh(false)
	assert_eq(clock.text, "0:09", "9 s = 0:09")
	clock.queue_free()


func test_room_code_shows_only_online_in_yellow() -> void:
	var label: RoomCodeLabel = RoomCodeLabel.new()
	get_root().add_child(label)
	label._refresh()
	assert_false(label.visible, "sin sala no se ve")
	NetworkManager.room_code = "K7QF"
	label._refresh()
	assert_true(label.visible, "con sala se ve")
	assert_eq(label.text, "K7QF", "el código de la sala")
	assert_eq(label.get_theme_color("font_color"), RoomCodeLabel.COLOR, "en amarillo")
	label.queue_free()
