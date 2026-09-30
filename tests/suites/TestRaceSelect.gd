extends TestSuite
## Selector de raza previo a la partida y precio creciente de las mejoras.

var _saved_race: StringName = &"human"


func before_each() -> void:
	_saved_race = GameManager.player_race
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 4444)


func after_each() -> void:
	GameManager.set_player_race(_saved_race, false)


func _make_select(mode: RaceSelect.Mode) -> RaceSelect:
	RaceSelect.next_mode = mode
	var select: RaceSelect = (load(RaceSelect.SCENE_PATH) as PackedScene).instantiate() as RaceSelect
	get_root().add_child(select)
	return select


func test_selector_starts_on_the_saved_race_and_rotates() -> void:
	GameManager.set_player_race(&"goblin", false)
	var select: RaceSelect = _make_select(RaceSelect.Mode.VS_AI)
	assert_eq(select.get_selected_race().id, &"goblin", "empieza en la última raza usada")
	select.select_race(0)
	assert_eq(select.get_selected_race().id, GameManager.database.races[0].id, "tocar otra tarjeta la pone al centro")
	assert_false(select.is_locked(), "aún no está fijada")
	select.queue_free()


func test_five_seconds_to_choose() -> void:
	assert_eq(RaceSelect.SECONDS, 5.0, "5 segundos")


func test_locking_saves_the_choice() -> void:
	var select: RaceSelect = _make_select(RaceSelect.Mode.ONLINE_HOST)
	select.select_race(2)
	var chosen: StringName = select.get_selected_race().id
	select.lock_choice()
	assert_true(select.is_locked(), "fijada")
	assert_eq(GameManager.player_race, chosen, "la raza elegida es la del jugador")
	select.select_race(0)
	assert_eq(select.get_selected_race().id, chosen, "ya no se puede cambiar")
	select.queue_free()


func test_info_lists_race_traits() -> void:
	var select: RaceSelect = _make_select(RaceSelect.Mode.VS_AI)
	var goblin: RaceData = GameManager.database.get_race(&"goblin")
	var text: String = select._stats_bbcode(goblin)
	assert_true(text.contains("+30 %") or text.contains("+10 %"), "muestra ajustes (cadencia/velocidad)")
	assert_true(text.contains("-20 %"), "y el precio más barato de las cartas")
	select.queue_free()


func test_buff_price_rises_ten_percent_per_copy() -> void:
	var card: CardData = GameManager.database.get_card(&"card_buff_armor")
	var buff: BuffData = card.buff
	var other: CardData = GameManager.database.get_card(&"card_buff_max_hp")
	var other_before: int = EconomyManager.get_card_cost(0, other)
	var base: int = EconomyManager.get_card_cost(0, card)
	assert_eq(base, roundi(float(card.cost) * GameManager.get_race(0).get_card_cost_multiplier(card)), "sin copias: precio base")
	BuffSystem.apply_buff(0, buff)
	var one: int = EconomyManager.get_card_cost(0, card)
	assert_true(absi(one - roundi(float(base) * 1.1)) <= 1, "1 copia: +10 %% (%d → %d)" % [base, one])
	BuffSystem.apply_buff(0, buff)
	var two: int = EconomyManager.get_card_cost(0, card)
	assert_true(absi(two - roundi(float(base) * 1.21)) <= 1, "2 copias: +21 %% acumulado (%d)" % two)
	assert_eq(EconomyManager.get_card_cost(0, other), other_before, "otras mejoras no suben")
