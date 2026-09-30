extends TestSuite
## Unidades especiales de cada raza (Caballería, Mago, Arquero venenoso) y habilidades
## de castillo (Lluvia de flechas, Rayo, Llamar a las milicias).

const STEP: float = 1.0 / 60.0
const DEBUG: GameCommand.Source = GameCommand.Source.DEBUG

var processor: CommandProcessor = null
var draft: DraftManager = null
var lane: LaneManager = null
var grid0: GridManager = null
var grid1: GridManager = null


func before_each() -> void:
	if processor == null:
		_build_fixture()
	GameManager.register_command_processor(processor)
	GameManager.match_races = [&"human", &"human"]
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 1717)
	lane.clear_units()


func after_all() -> void:
	GameManager.register_command_processor(null)
	GameManager.match_races = [&"human", &"human"]
	lane.clear_units()
	for node: Node in [processor, draft, lane, grid0, grid1]:
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
	for node: Node in [processor, draft, lane, grid0, grid1]:
		get_root().add_child(node)
	for grid: GridManager in [grid0, grid1]:
		grid.lane = lane
		processor.register_grid(grid)
	processor.register_lane(lane)
	processor.register_draft(draft)


func _unit(id: StringName) -> UnitData:
	return GameManager.database.get_unit(id)


func _run(seconds: float) -> void:
	for _step: int in roundi(seconds / STEP):
		GameManager.match_state.match_time += STEP
		lane.simulate_step(STEP)


## Unidad quieta y sin atacar (los tests miden efectos concretos, no combates).
func _spawn(id: StringName, team: int, y: float, x: float = 540.0) -> UnitBase:
	var unit: UnitBase = lane.spawn_unit(_unit(id), team, Vector2(x, y))
	unit.move_speed = 0.0
	unit.attack_cooldown_left = 99999.0
	return unit


## Coloca `count` estructuras del tipo en el grid del jugador (plots iniciales).
func _build_structures(player_id: int, card_id: StringName, count: int) -> void:
	EconomyManager.add_gold(player_id, 5000)
	var slots: Array[int] = [16, 17, 18, 19]
	for index: int in count:
		assert_true(GameManager.submit_command(BuildCommand.new(player_id, card_id, slots[index], DEBUG)), "construir %s #%d" % [card_id, index])


func _set_race(player_id: int, race_id: StringName) -> void:
	GameManager.get_player_state(player_id).race_id = race_id


func _available(player_id: int, card_id: StringName) -> bool:
	return draft.is_card_available(player_id, GameManager.database.get_card(card_id))


# --- Datos -------------------------------------------------------------------------

func test_special_units_stats_follow_the_design() -> void:
	var cavalry: UnitData = _unit(&"cavalry")
	assert_true(cavalry.max_hp > _unit(&"soldier").max_hp * 2.0, "caballería: mucha vida")
	assert_eq(cavalry.splash_fraction, 0.05, "caballería: 5 % en área")
	var mage: UnitData = _unit(&"mage")
	assert_true(mage.max_hp < _unit(&"archer").max_hp * 0.6, "mago: muy débil")
	assert_true(mage.damage > _unit(&"soldier").damage * 2.5, "mago: mucho daño")
	assert_eq(mage.splash_fraction, 0.15, "mago: 15 % en área")
	var venom: UnitData = _unit(&"venom_archer")
	assert_true(venom.has_poison(), "arquero venenoso: veneno")
	var costs: Dictionary = {}
	for card_id: StringName in [&"card_cavalry", &"card_mage", &"card_venom_archer"]:
		costs[card_id] = GameManager.database.get_card(card_id).cost
	assert_true(costs[&"card_venom_archer"] < costs[&"card_cavalry"] and costs[&"card_venom_archer"] < costs[&"card_mage"], "el arquero venenoso es la especial más barata")
	assert_eq(GameManager.database.get_validation_errors().size(), 0, "la base de datos sigue siendo válida")


# --- Cuándo aparecen sus cartas ---------------------------------------------------------

func test_special_cards_need_three_barracks_of_the_same_type() -> void:
	_set_race(0, &"human")
	_build_structures(0, &"card_soldier_barracks", 2)
	assert_false(_available(0, &"card_cavalry"), "2 cuarteles de soldados: aún no")
	_build_structures_at(0, &"card_soldier_barracks", 18)
	assert_true(_available(0, &"card_cavalry"), "3 cuarteles de soldados: aparece la Caballería")
	assert_false(_available(0, &"card_mage"), "la carta de los elfos no sale a humanos")
	assert_false(_available(0, &"card_venom_archer"), "ni la de los goblins")


func _build_structures_at(player_id: int, card_id: StringName, slot_index: int) -> void:
	EconomyManager.add_gold(player_id, 5000)
	assert_true(GameManager.submit_command(BuildCommand.new(player_id, card_id, slot_index, DEBUG)), "construir %s en %d" % [card_id, slot_index])


func test_mixed_barracks_do_not_unlock_special_units() -> void:
	_set_race(0, &"human")
	_build_structures_at(0, &"card_soldier_barracks", 16)
	_build_structures_at(0, &"card_soldier_barracks", 17)
	_build_structures_at(0, &"card_archer_barracks", 18)
	assert_false(_available(0, &"card_cavalry"), "2 de soldados + 1 de arqueros no cuentan como 3 del mismo tipo")
	assert_true(_available(0, &"card_tank"), "pero el Tank (3 cuarteles cualesquiera) sí")


func test_each_race_gets_only_its_special_unit() -> void:
	for race_id: StringName in [&"elf", &"goblin"]:
		GameManager.start_match(MatchTypes.GameMode.VS_AI, 1718)
		_set_race(0, race_id)
		_build_structures(0, &"card_archer_barracks", 3)
		assert_eq(_available(0, &"card_mage"), race_id == &"elf", "Mago solo para elfos (%s)" % race_id)
		assert_eq(_available(0, &"card_venom_archer"), race_id == &"goblin", "Arquero venenoso solo para goblins (%s)" % race_id)
		assert_false(_available(0, &"card_cavalry"), "sin Caballería fuera de los humanos (%s)" % race_id)


# --- Daño en área -------------------------------------------------------------------------

func test_cavalry_splashes_five_percent() -> void:
	var cavalry: UnitBase = _spawn(&"cavalry", 0, 1500.0)
	var main_target: UnitBase = _spawn(&"tank", 1, 1500.0 - cavalry.body_radius - 60.0 - 30.0)
	var neighbor: UnitBase = _spawn(&"tank", 1, main_target.global_position.y - 50.0, 640.0)
	var far_unit: UnitBase = _spawn(&"tank", 1, main_target.global_position.y - 400.0)
	main_target.damage_mitigation = 0.0
	neighbor.damage_mitigation = 0.0
	far_unit.damage_mitigation = 0.0
	# El tanque del frente y la caballería se golpean; miramos solo el primer golpe.
	lane.queue_hit(cavalry, main_target, cavalry.damage)
	lane._resolve_hits()
	assert_eq(main_target.max_hp - main_target.current_hp, cavalry.damage, "el objetivo recibe el golpe entero")
	assert_true(is_equal_approx(neighbor.max_hp - neighbor.current_hp, cavalry.damage * 0.05), "el vecino recibe el 5 %")
	assert_eq(far_unit.current_hp, far_unit.max_hp, "el lejano no recibe nada")


func test_mage_splashes_fifteen_percent_with_a_projectile() -> void:
	var mage: UnitBase = _spawn(&"mage", 0, 1700.0)
	var target: UnitBase = _spawn(&"tank", 1, 1500.0)
	var neighbor: UnitBase = _spawn(&"tank", 1, 1470.0, 600.0)
	target.damage_mitigation = 0.0
	neighbor.damage_mitigation = 0.0
	var projectile: Projectile = lane.spawn_projectile(mage.unit_id, 0, mage.global_position, target.unit_id, mage.damage, 3000.0)
	projectile.set_effects(mage.data)
	_run(0.5)
	assert_eq(target.max_hp - target.current_hp, mage.damage, "el objetivo recibe todo")
	assert_true(is_equal_approx(neighbor.max_hp - neighbor.current_hp, mage.damage * 0.15), "el vecino recibe el 15 %")


# --- Veneno --------------------------------------------------------------------------------

func test_venom_deals_damage_every_second_and_ignores_armor() -> void:
	var venom: UnitBase = _spawn(&"venom_archer", 0, 1700.0)
	var target: UnitBase = _spawn(&"tank", 1, 1500.0)
	target.damage_mitigation = 0.5
	var projectile: Projectile = lane.spawn_projectile(venom.unit_id, 0, venom.global_position, target.unit_id, 0.001, 3000.0)
	projectile.set_effects(venom.data)
	_run(0.3)
	var before: float = target.current_hp
	assert_true(target.poison_left > 0.0, "el objetivo queda envenenado")
	_run(2.0)
	var lost: float = before - target.current_hp
	assert_true(absf(lost - venom.data.poison_dps * 2.0) < venom.data.poison_dps * 0.6, "≈ %.0f de daño en 2 s, sin armadura (%.1f)" % [venom.data.poison_dps * 2.0, lost])
	_run(venom.data.poison_duration + 1.0)
	assert_eq(target.poison_left, 0.0, "el veneno se acaba")
	var after_expiry: float = target.current_hp
	_run(2.0)
	assert_eq(target.current_hp, after_expiry, "y ya no hace daño")


func test_poison_can_kill() -> void:
	var victim: UnitBase = _spawn(&"archer", 1, 1500.0)
	victim.apply_poison(30.0, 10.0)
	_run(6.0)
	assert_true(victim.is_dead, "el veneno mata a una unidad frágil")


# --- Habilidades de castillo ------------------------------------------------------------------

func _cast(player_id: int, spell_id: StringName, point: Vector2, source: GameCommand.Source = GameCommand.Source.LOCAL_PLAYER) -> bool:
	return GameManager.submit_command(CastSpellCommand.new(player_id, spell_id, point, source))


func test_three_spells_with_shared_thirty_second_cooldown() -> void:
	var ids: Array[StringName] = []
	for spell: SpellData in GameManager.database.spells:
		ids.append(spell.id)
		assert_eq(spell.cooldown, 30.0, "%s: 30 s de espera" % spell.id)
	assert_eq(ids, [&"arrow_rain", &"lightning", &"summon_militia"] as Array[StringName], "lluvia de flechas, rayo y milicias")


func test_arrow_rain_hurts_everyone_in_the_area_lightly() -> void:
	var victims: Array[UnitBase] = []
	for offset: float in [0.0, 60.0, -60.0]:
		victims.append(_spawn(&"tank", 1, 2000.0 + offset, 540.0 + offset))
	var outside: UnitBase = _spawn(&"tank", 1, 1300.0)
	for unit: UnitBase in victims + [outside]:
		unit.damage_mitigation = 0.0
	var ally: UnitBase = _spawn(&"tank", 0, 2000.0)
	assert_true(_cast(0, &"arrow_rain", Vector2(540.0, 2000.0)), "lluvia lanzada en mi mitad")
	_run(4.0)
	var spell: SpellData = GameManager.database.get_spell(&"arrow_rain")
	var expected: float = spell.damage * spell.waves
	for unit: UnitBase in victims:
		assert_true(is_equal_approx(unit.max_hp - unit.current_hp, expected), "%.0f de daño ligero en total" % expected)
	assert_eq(outside.current_hp, outside.max_hp, "fuera del círculo no pasa nada")
	assert_eq(ally.current_hp, ally.max_hp, "no daña a las tropas propias")
	assert_true(expected < victims[0].max_hp * 0.25, "es un daño ligero")


func test_lightning_kills_one_unit_whatever_its_health() -> void:
	var tank: UnitBase = _spawn(&"tank", 1, 2000.0)
	var neighbor: UnitBase = _spawn(&"tank", 1, 2000.0, 700.0)
	assert_true(_cast(0, &"lightning", Vector2(545.0, 2010.0)), "rayo lanzado")
	assert_true(tank.is_dead, "el tanque muere de un rayo")
	assert_false(neighbor.is_dead, "solo una unidad")
	assert_eq(neighbor.current_hp, neighbor.max_hp, "la vecina sin un rasguño")


func test_lightning_without_enemies_is_not_spent() -> void:
	assert_false(_cast(0, &"lightning", Vector2(540.0, 2000.0)), "sin enemigos cerca no se lanza")
	_spawn(&"soldier", 1, 2000.0)
	assert_true(_cast(0, &"lightning", Vector2(540.0, 2000.0)), "y como no gastó la espera, ahora sí")


func test_militia_appears_and_disappears() -> void:
	var spell: SpellData = GameManager.database.get_spell(&"summon_militia")
	assert_true(_cast(0, &"summon_militia", Vector2(540.0, 2100.0)), "milicias invocadas")
	var militia: Array[UnitBase] = []
	for unit: UnitBase in lane.get_alive_units():
		if unit.data.id == &"militia" and unit.team == 0:
			militia.append(unit)
	assert_eq(militia.size(), spell.unit_count, "grupo de %d milicianos" % spell.unit_count)
	assert_true(militia[0].max_hp < _unit(&"soldier").max_hp * 0.3, "son débiles")
	_run(spell.unit.lifetime - 1.0)
	assert_false(militia[0].is_dead, "siguen a 1 s del final")
	_run(2.0)
	for unit: UnitBase in militia:
		assert_true(unit.is_dead, "desaparecen tras %.0f s" % spell.unit.lifetime)


func test_militia_ignores_the_troop_cap() -> void:
	GameManager.get_rules().unit_cap_override = 1
	_spawn(&"soldier", 0, 2200.0)
	assert_true(_cast(0, &"summon_militia", Vector2(540.0, 2100.0)), "aunque el tope esté lleno")
	GameManager.get_rules().unit_cap_override = 120


func test_spell_cooldown_and_zone_rules() -> void:
	_spawn(&"soldier", 1, 1200.0)
	assert_false(_cast(0, &"arrow_rain", Vector2(540.0, 1200.0)), "no se puede lanzar en la mitad rival")
	assert_true(_cast(0, &"arrow_rain", Vector2(540.0, 2100.0)), "en la propia sí")
	assert_false(_cast(0, &"arrow_rain", Vector2(540.0, 2100.0)), "en enfriamiento")
	assert_false(_cast(0, &"summon_militia", Vector2(540.0, 2100.0)), "la espera es compartida: los otros también esperan")
	assert_false(_cast(0, &"lightning", Vector2(540.0, 1900.0)), "incluido el rayo")
	_run(29.0)
	assert_false(_cast(0, &"summon_militia", Vector2(540.0, 2100.0)), "a los 29 s aún no")
	_run(1.5)
	assert_true(_cast(0, &"summon_militia", Vector2(540.0, 2100.0)), "a los 30 s se puede lanzar cualquiera")
	assert_false(_cast(0, &"arrow_rain", Vector2(540.0, 2100.0)), "y vuelven a esperar todos")
	assert_false(_cast(1, &"arrow_rain", Vector2(540.0, 2100.0)), "el jugador local no actúa por el rival")


func test_spell_events_codec_and_snapshot() -> void:
	var events: Array[Array] = []
	var listener: Callable = func(player_id: int, spell_id: StringName, position: Vector2) -> void: events.append([player_id, spell_id, position])
	EventBus.hechizo_lanzado.connect(listener)
	assert_true(_cast(0, &"summon_militia", Vector2(500.0, 2100.0)), "lanzado")
	EventBus.hechizo_lanzado.disconnect(listener)
	assert_eq(events.size(), 1, "un evento")
	assert_eq(events[0][1], &"summon_militia", "hechizo del evento")
	var decoded: CastSpellCommand = CommandCodec.decode(CommandCodec.encode(CastSpellCommand.new(0, &"lightning", Vector2(1.0, 2.0)))) as CastSpellCommand
	assert_true(decoded != null, "decodifica cast_spell")
	assert_eq(decoded.spell_id, &"lightning", "spell_id")
	assert_eq(decoded.position, Vector2(1.0, 2.0), "posición")
	assert_eq(decoded.source, GameCommand.Source.NETWORK, "source NETWORK")
	assert_true(CommandCodec.decode({"type": "cast_spell", "spell_id": "summon_militia"}) == null, "sin posición no se decodifica")
	var player_dict: Dictionary = GameManager.get_player_state(0).to_dict()
	assert_eq(player_dict["spell_seq"], 1, "snapshot: contador")
	assert_true(float((player_dict["spells"] as Dictionary)["summon_militia"]) > 0.0, "snapshot: tiempo de espera")
