extends TestSuite
## Fase 1: todos los datos del juego existen como Resources válidos y
## coinciden con la especificación.

var db: GameDatabase


func before_each() -> void:
	db = GameManager.database


func test_database_loads_and_validates() -> void:
	assert_true(db != null, "GameDatabase no cargó")
	if db == null:
		return
	var errors: PackedStringArray = db.get_validation_errors()
	assert_eq(errors.size(), 0, "errores de validación: %s" % ", ".join(errors))
	assert_eq(db.units.size(), 8, "número de unidades (4 base + 3 especiales + milicia)")
	assert_eq(db.structures.size(), 5, "número de estructuras")
	assert_eq(db.buffs.size(), 6, "número de buffs")
	assert_eq(db.cards.size(), 17, "número de cartas")


func test_lookup_by_id() -> void:
	assert_true(db.get_unit(&"soldier") != null, "soldier por id")
	assert_true(db.get_structure(&"farm") != null, "farm por id")
	assert_true(db.get_card(&"card_tank") != null, "card_tank por id")
	assert_true(db.get_buff(&"buff_armor") != null, "buff_armor por id")
	assert_true(db.get_unit(&"dragon") == null, "id inexistente devuelve null")


func test_resources_are_shared_files() -> void:
	# Editar data/units/soldier.tres debe afectar a barracks y cartas.
	var soldier: UnitData = db.get_unit(&"soldier")
	assert_eq(soldier.resource_path, "res://data/units/soldier.tres", "soldier es un archivo propio")
	assert_true(db.get_structure(&"soldier_barracks").spawn_unit == soldier, "barracks referencia el mismo soldier")
	assert_true(db.get_card(&"card_soldiers").unit == soldier, "carta referencia el mismo soldier")


func test_soldier_stats() -> void:
	var unit: UnitData = db.get_unit(&"soldier")
	_assert_unit(unit, 250.0, 120.0, 45.0, 1.2, 35.0, 0.0)
	assert_eq(unit.role, UnitData.Role.MELEE, "soldier MELEE")


func test_archer_stats() -> void:
	var unit: UnitData = db.get_unit(&"archer")
	_assert_unit(unit, 110.0, 100.0, 280.0, 0.9, 42.0, 0.0)
	assert_eq(unit.role, UnitData.Role.RANGED, "archer RANGED")
	assert_true(unit.uses_projectile, "archer usa proyectil")


func test_tank_stats() -> void:
	var unit: UnitData = db.get_unit(&"tank")
	_assert_unit(unit, 850.0, 70.0, 50.0, 2.0, 25.0, 0.2)
	assert_true(is_equal_approx(100.0 * (1.0 - unit.damage_mitigation), 80.0), "tank recibe incoming × 0.8")


func test_priest_stats() -> void:
	var unit: UnitData = db.get_unit(&"priest")
	assert_true(unit.is_healer(), "priest es HEALER")
	assert_eq(unit.max_hp, 140.0, "priest hp")
	assert_eq(unit.move_speed, 95.0, "priest speed")
	assert_eq(unit.attack_range, 220.0, "priest range")
	assert_eq(unit.attack_cooldown, 2.5, "priest cooldown")
	assert_eq(unit.heal_amount, 45.0, "priest heal")


func test_farm_income_per_level() -> void:
	var farm: StructureData = db.get_structure(&"farm")
	assert_eq(farm.kind, StructureData.Kind.FARM, "farm kind")
	var expected: Array[int] = [25, 40, 60, 80, 100]
	for level: int in range(1, 6):
		assert_eq(farm.get_income(level), expected[level - 1], "farm income Lv%d" % level)
	assert_eq(farm.income_interval, 8.0, "farm interval")
	assert_eq(farm.get_income(9), 100, "nivel por encima del máximo se limita a Lv5")


func test_soldier_barracks_level1() -> void:
	var barracks: StructureData = db.get_structure(&"soldier_barracks")
	assert_eq(barracks.get_spawn_count(1), 2, "2 soldiers")
	assert_eq(barracks.get_spawn_interval(1), 8.0, "cada 8 s")
	assert_true(barracks.spawn_unit == db.get_unit(&"soldier"), "genera soldiers")


func test_church_conversion_rules() -> void:
	var church: StructureData = db.get_structure(&"church")
	assert_true(church.spawn_unit == db.get_unit(&"priest"), "church genera priests")
	assert_false(church.enables_conversion(2), "Lv2 sin conversión")
	assert_true(church.enables_conversion(3), "Lv3 con conversión")
	assert_true(is_equal_approx(church.conversion_chance, 0.05), "5 %")
	assert_eq(church.conversion_max_target_hp, 600.0, "max_hp <= 600")
	assert_false(db.get_structure(&"soldier_barracks").enables_conversion(5), "barracks nunca convierte")


func test_all_structures_have_five_levels() -> void:
	for structure: StructureData in db.structures:
		assert_eq(structure.max_level, 5, "%s max_level" % structure.id)
		assert_true(structure.is_valid_level(5), "%s acepta Lv5" % structure.id)
		assert_false(structure.is_valid_level(6), "%s rechaza Lv6" % structure.id)
		assert_false(structure.is_valid_level(0), "%s rechaza Lv0" % structure.id)


func test_barracks_tags() -> void:
	assert_true(db.get_structure(&"soldier_barracks").has_tag(&"barracks"), "soldier barracks es cuartel")
	assert_true(db.get_structure(&"archer_barracks").has_tag(&"barracks"), "archer barracks es cuartel")
	assert_false(db.get_structure(&"church").has_tag(&"barracks"), "church no es cuartel")


func test_cards_cover_all_types() -> void:
	var counts: Dictionary[int, int] = {}
	for card: CardData in db.cards:
		counts[card.card_type] = counts.get(card.card_type, 0) + 1
		assert_true(card.cost > 0, "%s tiene coste" % card.id)
	assert_eq(counts.get(CardData.CardType.STRUCTURE, 0), 5, "5 cartas de estructura")
	assert_eq(counts.get(CardData.CardType.DIRECT_UNIT, 0), 6, "6 cartas de unidad (3 base + 3 especiales)")
	assert_eq(counts.get(CardData.CardType.GLOBAL_BUFF, 0), 6, "6 cartas de buff")


func test_card_drop_targets() -> void:
	assert_eq(db.get_card(&"card_farm").get_drop_target(), CardData.DropTarget.PLOT, "estructura → plot")
	assert_eq(db.get_card(&"card_soldiers").get_drop_target(), CardData.DropTarget.LANE, "unidad → carril")
	assert_eq(db.get_card(&"card_buff_armor").get_drop_target(), CardData.DropTarget.ANYWHERE, "buff → cualquier sitio")


func test_tank_card_requires_three_barracks() -> void:
	var card: CardData = db.get_card(&"card_tank")
	assert_true(card.has_unlock_requirement(), "tank tiene requisito")
	assert_eq(card.required_structure_tag, &"barracks", "requisito: cuarteles")
	assert_eq(card.required_structure_count, 3, "requisito: 3")
	assert_false(db.get_card(&"card_soldiers").has_unlock_requirement(), "soldiers sin requisito")


func test_buff_definitions() -> void:
	var speed: BuffData = db.get_buff(&"buff_move_speed")
	assert_eq(speed.stat, BuffData.Stat.MOVE_SPEED, "speed stat")
	assert_true(is_equal_approx(speed.value, 0.15), "+15 %")
	var production: BuffData = db.get_buff(&"buff_production")
	assert_eq(production.stat, BuffData.Stat.PRODUCTION_INTERVAL, "production stat")
	assert_true(is_equal_approx(production.value, -1.5), "-1.5 s")
	assert_true(speed.affects_unit(&"tank"), "sin filtro afecta a todas")


func test_game_rules() -> void:
	var rules: GameRules = db.rules
	assert_eq(rules.starting_gold, 20, "oro inicial")
	assert_eq(rules.base_income_amount, 5, "+5")
	assert_eq(rules.base_income_interval, 3.0, "cada 3 s")
	assert_eq(rules.castle_max_hp, 3000.0, "HP castillo")
	assert_eq(rules.reroll_base_cost, 10, "reroll base")
	assert_eq(rules.reroll_cost_increment, 3, "reroll +3")
	assert_eq(rules.reroll_decay_amount, 1, "reroll -1")
	assert_eq(rules.reroll_decay_interval, 10.0, "cada 10 s")
	assert_eq(rules.get_sell_refund(61), 30, "venta devuelve la mitad (redondeo hacia abajo)")
	assert_eq(rules.plot_costs.size(), GameRules.PLOT_COUNT, "6 plots")
	assert_eq(rules.get_plot_cost(4), 0, "plot inicial gratis")
	assert_eq(rules.get_plot_cost(9), -1, "plot inválido")


func test_validation_detects_bad_data() -> void:
	var bad_unit: UnitData = UnitData.new()
	bad_unit.id = &"bad"
	bad_unit.max_hp = 0.0
	assert_true(bad_unit.get_validation_errors().size() > 0, "unidad con hp 0 es inválida")
	var bad_card: CardData = CardData.new()
	bad_card.id = &"bad_card"
	bad_card.card_type = CardData.CardType.STRUCTURE
	assert_true(bad_card.get_validation_errors().size() > 0, "carta STRUCTURE sin structure es inválida")
	var bad_structure: StructureData = StructureData.new()
	bad_structure.id = &"bad_structure"
	bad_structure.income_per_level = PackedInt32Array([10, 20])
	assert_true(bad_structure.get_validation_errors().size() > 0, "farm con 2 niveles es inválida")


func _assert_unit(unit: UnitData, hp: float, speed: float, attack_range: float, cooldown: float, damage: float, mitigation: float) -> void:
	assert_true(unit != null, "unidad nula")
	if unit == null:
		return
	assert_eq(unit.max_hp, hp, "%s hp" % unit.id)
	assert_eq(unit.move_speed, speed, "%s speed" % unit.id)
	assert_eq(unit.attack_range, attack_range, "%s range" % unit.id)
	assert_true(is_equal_approx(unit.attack_cooldown, cooldown), "%s cooldown" % unit.id)
	assert_eq(unit.damage, damage, "%s damage" % unit.id)
	assert_true(is_equal_approx(unit.damage_mitigation, mitigation), "%s mitigation" % unit.id)
