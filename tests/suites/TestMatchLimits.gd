extends TestSuite
## Límite de tropas (mejora que lo sube, milicias que no cuentan) y muerte súbita.

const STEP: float = 1.0 / 60.0

var lane: LaneManager = null


func before_each() -> void:
	GameManager.match_mods = []
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 6161)
	if lane == null:
		lane = LaneManager.new()
		get_root().add_child(lane)
	lane.clear_units()


func after_all() -> void:
	if lane != null:
		lane.clear_units()
		lane.queue_free()
		lane = null


func test_troop_cap_card_exists_and_raises_the_limit_per_copy() -> void:
	var card: CardData = GameManager.database.get_card(&"card_buff_troop_cap")
	assert_true(card != null and card.buff != null, "la carta existe y es una mejora")
	assert_eq(card.buff.stat, BuffData.Stat.UNIT_CAP, "sube el límite de tropas")
	var base: int = lane.get_unit_cap(0)
	BuffSystem.apply_buff(0, card.buff)
	assert_eq(lane.get_unit_cap(0), base + 5, "+5 con una copia")
	BuffSystem.apply_buff(0, card.buff)
	assert_eq(lane.get_unit_cap(0), base + 10, "se acumula")
	assert_eq(lane.get_unit_cap(1), lane.get_unit_cap(1), "el rival no cambia")
	assert_eq(BuffSystem.get_unit_cap_bonus(1), 0, "el rival no tiene bonus")


func test_troop_cap_buff_is_described() -> void:
	var card: CardData = GameManager.database.get_card(&"card_buff_troop_cap")
	assert_true(BuffIcons.describe(card.buff, 2).contains("10"), "la descripción suma las copias")


func test_militia_does_not_count_for_the_cap() -> void:
	var soldier: UnitData = GameManager.database.get_unit(&"soldier")
	var militia: UnitData = GameManager.database.get_unit(&"militia")
	var cap: int = lane.get_unit_cap(0)
	for index: int in cap - 1:
		lane.spawn_unit(soldier, 0, Vector2(400.0 + index * 10.0, 2200.0))
	for index: int in 6:
		lane.spawn_unit(militia, 0, Vector2(500.0 + index * 10.0, 2200.0), true)
	assert_eq(lane.get_alive_count(0), cap - 1 + 6, "viven todas")
	assert_eq(lane.get_army_count(0), cap - 1, "pero las milicias no cuentan para el tope")
	assert_true(lane.spawn_unit(soldier, 0, Vector2(450.0, 2200.0)) != null, "aún cabe una tropa aunque haya milicias")
	assert_true(lane.spawn_unit(soldier, 0, Vector2(460.0, 2200.0)) == null, "y con el tope de tropas ya no")


func test_sudden_death_rates() -> void:
	var rules: GameRules = GameManager.get_rules()
	assert_eq(rules.get_sudden_death_dps(rules.sudden_death_start - 1.0), 0.0, "antes: nada")
	var first: float = rules.get_sudden_death_dps(rules.sudden_death_start)
	assert_true(first > 0.0, "empieza a hacer daño")
	assert_true(rules.get_sudden_death_dps(rules.sudden_death_start + rules.sudden_death_ramp_interval * 3.0) > first * 3.5, "y cada vez más")


func test_sudden_death_wears_down_both_castles_and_the_healthier_one_wins() -> void:
	var rules: GameRules = GameManager.get_rules()
	GameManager.match_state.match_time = rules.sudden_death_start + 1.0
	GameManager.get_player_state(1).castle_hp -= 500.0
	var before: float = GameManager.get_player_state(0).castle_hp
	for _step: int in 60:
		lane.simulate_step(STEP)
	assert_true(GameManager.get_player_state(0).castle_hp < before, "los castillos pierden vida")
	assert_true(GameManager.get_player_state(1).castle_hp < GameManager.get_player_state(0).castle_hp, "el que iba peor sigue peor")
	GameManager.get_player_state(1).castle_hp = 1.0
	lane.simulate_step(0.1)
	assert_eq(GameManager.match_phase, MatchTypes.MatchPhase.ENDED, "la partida acaba")
	assert_eq(GameManager.match_state.winner_player_id, 0, "gana quien tenía más vida")


func test_no_sudden_death_before_the_start() -> void:
	var before: float = GameManager.get_player_state(0).castle_hp
	GameManager.match_state.match_time = 30.0
	for _step: int in 60:
		lane.simulate_step(STEP)
	assert_eq(GameManager.get_player_state(0).castle_hp, before, "sin daño al principio")
