extends TestSuite
## Fases 7-8: comportamiento y producción de cada estructura.
##   Farm → Economy · Barracks → Lane · Church → Lane · Tower → Combat

const STEP: float = 1.0 / 60.0
const DEBUG: GameCommand.Source = GameCommand.Source.DEBUG
## Plot inicial (gratis) = 4 (fila trasera) → slots 16..19.
const START_SLOT: int = 16

var processor: CommandProcessor = null
var grid0: GridManager = null
var grid1: GridManager = null
var lane: LaneManager = null


func before_each() -> void:
	if processor == null:
		_build_fixture()
	GameManager.register_command_processor(processor)
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 808)
	EconomyManager.add_gold(0, 1000)


func after_all() -> void:
	GameManager.register_command_processor(null)
	lane.clear_units()
	for node: Node in [processor, grid0, grid1, lane]:
		node.queue_free()


func _build_fixture() -> void:
	processor = CommandProcessor.new()
	lane = LaneManager.new()
	grid0 = GridManager.new()
	grid0.player_id = 0
	grid0.position = Vector2(30.0, 2460.0)
	grid1 = GridManager.new()
	grid1.player_id = 1
	grid1.position = Vector2(30.0, 40.0)
	for node: Node in [processor, lane, grid0, grid1]:
		get_root().add_child(node)
	for grid: GridManager in [grid0, grid1]:
		grid.lane = lane
		processor.register_grid(grid)
	processor.register_lane(lane)


func _tick(seconds: float) -> void:
	for _step: int in roundi(seconds / STEP):
		grid0.simulate_step(STEP)
		grid1.simulate_step(STEP)
		lane.simulate_step(STEP)


func _build(card_id: StringName, slot_index: int, player_id: int = 0) -> void:
	var ok: bool = GameManager.submit_command(BuildCommand.new(player_id, card_id, slot_index, DEBUG))
	assert_true(ok, "construir %s en slot %d" % [card_id, slot_index])


func _gold() -> int:
	return EconomyManager.get_gold(0)


func _units_of(team: int, unit_id: StringName) -> Array[UnitBase]:
	var result: Array[UnitBase] = []
	for unit: UnitBase in lane.get_alive_units():
		if unit.team == team and unit.data.id == unit_id:
			result.append(unit)
	return result


# --- Nivel compartido ------------------------------------------------------------

func test_every_structure_of_a_type_levels_up_together() -> void:
	for slot_index: int in [16, 17, 18]:
		_build(&"card_tower", slot_index)
		for built_slot: int in range(16, slot_index + 1):
			assert_eq(grid0.get_structure_at(built_slot).level, slot_index - 15, "torre del slot %d tras construir %d" % [built_slot, slot_index - 15])
	# Aunque un nodo se quedara con un nivel viejo, la comprobación periódica lo corrige.
	grid0.get_structure_at(16).set_level(1)
	grid0.get_structure_at(17).set_level(2)
	grid0._reconcile_levels()
	for slot_index: int in [16, 17, 18]:
		assert_eq(grid0.get_structure_at(slot_index).level, 3, "nivel corregido en slot %d" % slot_index)


# --- Farm → Economy ------------------------------------------------------------

func test_farm_lv1_gives_25_every_8s() -> void:
	_build(&"card_farm", START_SLOT)
	var after_build: int = _gold()
	_tick(7.9)
	assert_eq(_gold(), after_build, "sin ingreso antes de 8 s")
	_tick(0.2)
	assert_eq(_gold(), after_build + 25, "+25 a los 8 s")


func test_farm_levels_share_total_income() -> void:
	var expected_totals: Array[int] = [25, 40, 60, 80, 100]
	GameManager.submit_command(UnlockPlotCommand.new(0, 5, DEBUG))
	var slots: Array[int] = [16, 17, 18, 19, 20]
	for farm_count: int in range(1, 6):
		GameManager.start_match(MatchTypes.GameMode.VS_AI, 808)
		EconomyManager.add_gold(0, 1000)
		GameManager.submit_command(UnlockPlotCommand.new(0, 5, DEBUG))
		for index: int in farm_count:
			_build(&"card_farm", slots[index])
		var before: int = _gold()
		_tick(8.05)
		assert_eq(_gold() - before, expected_totals[farm_count - 1], "Lv%d: total por ciclo" % farm_count)


func test_farm_per_building_mode() -> void:
	var farm: StructureData = GameManager.database.get_structure(&"farm")
	farm.income_shared_between_buildings = false
	_build(&"card_farm", 16)
	_build(&"card_farm", 17)
	var before: int = _gold()
	_tick(8.05)
	farm.income_shared_between_buildings = true
	assert_eq(_gold() - before, 80, "modo por edificio: 2 granjas Lv2 = 40 + 40")


func test_sold_farm_stops_producing() -> void:
	_build(&"card_farm", START_SLOT)
	GameManager.submit_command(SellCommand.new(0, START_SLOT, DEBUG))
	var after_sell: int = _gold()
	_tick(8.5)
	assert_eq(_gold(), after_sell, "una granja vendida no produce")


# --- Barracks → Lane -----------------------------------------------------------

func test_soldier_barracks_spawns_two_every_8s() -> void:
	_build(&"card_soldier_barracks", START_SLOT)
	_tick(7.9)
	assert_eq(_units_of(0, &"soldier").size(), 0, "nada antes de 8 s")
	_tick(0.2)
	var soldiers: Array[UnitBase] = _units_of(0, &"soldier")
	assert_eq(soldiers.size(), 2, "2 soldiers a los 8 s")
	for unit: UnitBase in soldiers:
		assert_eq(unit.max_hp, 250.0, "un cuartel: vida base")
		assert_eq(unit.damage, 35.0, "un cuartel: daño base")


func test_each_extra_barracks_improves_units() -> void:
	_build(&"card_soldier_barracks", 16)
	_build(&"card_soldier_barracks", 17)
	# Lv2 = 2 cuarteles: 2 soldiers cada 7.5 s cada uno.
	_tick(7.6)
	var soldiers: Array[UnitBase] = _units_of(0, &"soldier")
	assert_eq(soldiers.size(), 4, "2 cuarteles × 2 soldiers")
	for unit: UnitBase in soldiers:
		assert_eq(unit.max_hp, 260.0, "+10 de vida por el 2.º cuartel")
		assert_eq(unit.damage, 36.0, "+1 de daño por el 2.º cuartel")


func test_barracks_bonus_only_for_its_unit() -> void:
	_build(&"card_soldier_barracks", 16)
	_build(&"card_soldier_barracks", 17)
	_build(&"card_soldier_barracks", 18)
	var soldier_mods: UnitStatModifiers = UnitStatModifiers.from_barracks(0, GameManager.database.get_unit(&"soldier"))
	var archer_mods: UnitStatModifiers = UnitStatModifiers.from_barracks(0, GameManager.database.get_unit(&"archer"))
	var enemy_mods: UnitStatModifiers = UnitStatModifiers.from_barracks(1, GameManager.database.get_unit(&"soldier"))
	assert_eq(soldier_mods.bonus_max_hp, 20.0, "3 cuarteles: +20 vida")
	assert_eq(soldier_mods.bonus_damage, 2.0, "3 cuarteles: +2 daño")
	assert_eq(archer_mods.bonus_max_hp, 0.0, "los archers no se benefician")
	assert_eq(enemy_mods.bonus_damage, 0.0, "el rival no se beneficia")


func test_archer_barracks_spawns_one_every_8s() -> void:
	_build(&"card_archer_barracks", START_SLOT)
	_tick(8.1)
	assert_eq(_units_of(0, &"archer").size(), 1, "1 archer a los 8 s")


func test_barracks_units_spawn_for_their_owner() -> void:
	EconomyManager.add_gold(1, 1000)
	_build(&"card_soldier_barracks", START_SLOT, 1)
	_tick(8.1)
	assert_eq(_units_of(1, &"soldier").size(), 2, "soldiers del player 1")
	assert_eq(_units_of(0, &"soldier").size(), 0, "ninguno para el player 0")
	for unit: UnitBase in _units_of(1, &"soldier"):
		assert_true(unit.global_position.y < 1100.0, "aparecen en el extremo del player 1")


func test_sold_barracks_stops_spawning() -> void:
	_build(&"card_soldier_barracks", START_SLOT)
	_tick(4.0)
	GameManager.submit_command(SellCommand.new(0, START_SLOT, DEBUG))
	_tick(8.0)
	assert_eq(_units_of(0, &"soldier").size(), 0, "vendido antes de producir")


# --- Church → Lane -------------------------------------------------------------

func test_church_spawns_priest_every_12s() -> void:
	_build(&"card_church", START_SLOT)
	_tick(11.9)
	assert_eq(_units_of(0, &"priest").size(), 0, "nada antes de 12 s")
	_tick(0.2)
	var priests: Array[UnitBase] = _units_of(0, &"priest")
	assert_eq(priests.size(), 1, "1 priest a los 12 s")
	assert_eq(priests[0].damage, 0.0, "el priest no gana daño")


# --- Tower → Combat ------------------------------------------------------------

func test_front_row_tower_shoots_enemy_in_range() -> void:
	GameManager.submit_command(UnlockPlotCommand.new(0, 1, DEBUG))
	_build(&"card_tower", 4)
	var enemy: UnitBase = lane.spawn_unit(GameManager.database.get_unit(&"soldier"), 1, Vector2(540.0, 2250.0))
	_tick(0.5)
	assert_true(enemy.current_hp < 250.0, "la torre daña al enemigo en rango (vida %.0f)" % enemy.current_hp)
	assert_eq(fmod(250.0 - enemy.current_hp, 30.0), 0.0, "daño en múltiplos de 30 (Tower Lv1)")


func test_tower_ignores_far_enemies_and_allies() -> void:
	GameManager.submit_command(UnlockPlotCommand.new(0, 1, DEBUG))
	_build(&"card_tower", 4)
	lane.spawn_unit(GameManager.database.get_unit(&"soldier"), 1, Vector2(540.0, 1500.0))
	var ally: UnitBase = lane.spawn_unit(GameManager.database.get_unit(&"soldier"), 0, Vector2(540.0, 2250.0))
	_tick(0.2)
	assert_eq(lane.get_projectile_count(), 0, "sin disparos: enemigo lejos")
	assert_eq(ally.current_hp, 250.0, "nunca dispara a aliados")


func test_back_row_tower_cannot_reach_lane() -> void:
	_build(&"card_tower", START_SLOT)
	var enemy: UnitBase = lane.spawn_unit(GameManager.database.get_unit(&"soldier"), 1, Vector2(540.0, 2250.0))
	_tick(1.0)
	assert_eq(enemy.current_hp, 250.0, "la fila trasera queda fuera de rango del carril")


# --- General -------------------------------------------------------------------

func test_structures_stop_after_match_end() -> void:
	_build(&"card_farm", START_SLOT)
	_build(&"card_soldier_barracks", 17)
	var gold_before: int = _gold()
	GameManager.end_match(MatchTypes.NO_PLAYER)
	_tick(9.0)
	assert_eq(_gold(), gold_before, "sin ingresos")
	assert_eq(lane.get_alive_units().size(), 0, "sin producción")
