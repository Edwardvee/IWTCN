extends TestSuite
## Fase 9: tienda de cartas, reroll, jugar cartas y martillo.

const STEP: float = 1.0 / 60.0
const START_SLOT: int = 16

var processor: CommandProcessor = null
var draft: DraftManager = null
var grid0: GridManager = null
var grid1: GridManager = null
var lane: LaneManager = null
var input: LocalInputController = null


func before_each() -> void:
	if processor == null:
		_build_fixture()
	GameManager.register_command_processor(processor)
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 909)


func after_all() -> void:
	GameManager.register_command_processor(null)
	lane.clear_units()
	for node: Node in [processor, draft, grid0, grid1, lane, input]:
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
	input = LocalInputController.new()
	for node: Node in [processor, draft, lane, grid0, grid1, input]:
		get_root().add_child(node)
	for grid: GridManager in [grid0, grid1]:
		grid.lane = lane
		processor.register_grid(grid)
		input.register_grid(grid)
	processor.register_lane(lane)
	processor.register_draft(draft)
	input.lane = lane


func _offer_ids(player_id: int) -> Array[StringName]:
	return GameManager.get_player_state(player_id).shop.offer.duplicate()


func _gold(player_id: int = 0) -> int:
	return EconomyManager.get_gold(player_id)


func _play(offer_index: int, slot_index: int = -1, deploy: Vector2 = Vector2.ZERO) -> bool:
	return GameManager.submit_command(PlayCardCommand.new(0, offer_index, draft.get_offer_card_id(0, offer_index), slot_index, deploy))


# --- Oferta --------------------------------------------------------------------

func test_initial_offer_has_three_distinct_cards() -> void:
	for player_id: int in MatchTypes.PLAYER_COUNT:
		var offer: Array[StringName] = _offer_ids(player_id)
		assert_eq(offer.size(), 3, "P%d: 3 cartas" % player_id)
		var unique: Dictionary[StringName, bool] = {}
		for card_id: StringName in offer:
			unique[card_id] = true
		assert_eq(unique.size(), 3, "P%d: cartas distintas" % player_id)


func test_offers_are_always_distinct_over_many_rolls() -> void:
	for _roll: int in 200:
		draft.refresh_offer(0)
		var offer: Array[StringName] = _offer_ids(0)
		assert_true(offer[0] != offer[1] and offer[0] != offer[2] and offer[1] != offer[2], "distintas: %s" % str(offer))


func test_offer_is_deterministic_per_seed() -> void:
	var first: Array[StringName] = _offer_ids(0)
	var first_rival: Array[StringName] = _offer_ids(1)
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 909)
	assert_eq(_offer_ids(0), first, "misma semilla → misma tienda")
	assert_eq(_offer_ids(1), first_rival, "también para el rival")


func test_no_buff_cards_until_phase_10() -> void:
	for _roll: int in 100:
		draft.refresh_offer(0)
		for card: CardData in draft.get_offer(0):
			assert_true(card.card_type != CardData.CardType.GLOBAL_BUFF, "sin mejoras globales todavía")


func test_tank_only_with_three_barracks() -> void:
	var tank_seen: bool = false
	for _roll: int in 150:
		draft.refresh_offer(0)
		tank_seen = tank_seen or _offer_ids(0).has(&"card_tank")
	assert_false(tank_seen, "sin cuarteles el Tank no aparece")
	EconomyManager.add_gold(0, 1000)
	for slot_index: int in [16, 17, 18]:
		GameManager.submit_command(BuildCommand.new(0, &"card_soldier_barracks", slot_index, GameCommand.Source.DEBUG))
	assert_true(draft.is_card_available(0, GameManager.database.get_card(&"card_tank")), "3 cuarteles desbloquean el Tank")
	for _roll: int in 150:
		draft.refresh_offer(0)
		tank_seen = tank_seen or _offer_ids(0).has(&"card_tank")
	assert_true(tank_seen, "con 3 cuarteles el Tank aparece")
	assert_false(draft.is_card_available(1, GameManager.database.get_card(&"card_tank")), "el rival sigue sin Tank")


func test_maxed_structure_not_offered() -> void:
	EconomyManager.add_gold(0, 1000)
	GameManager.submit_command(UnlockPlotCommand.new(0, 5))
	for slot_index: int in [16, 17, 18, 19, 20]:
		GameManager.submit_command(BuildCommand.new(0, &"card_farm", slot_index, GameCommand.Source.DEBUG))
	assert_false(draft.is_card_available(0, GameManager.database.get_card(&"card_farm")), "Farm Lv5 ya no se ofrece")


# --- Reroll --------------------------------------------------------------------

func test_reroll_costs_and_increases() -> void:
	assert_eq(draft.get_reroll_cost(0), 10, "coste base 10")
	assert_true(GameManager.submit_command(RerollShopCommand.new(0)), "reroll con 20 de oro")
	assert_eq(_gold(), 10, "20 - 10")
	assert_eq(draft.get_reroll_cost(0), 13, "+3 por reroll")
	assert_false(GameManager.submit_command(RerollShopCommand.new(0)), "10 < 13: rechazado")
	assert_eq(_gold(), 10, "oro intacto")


func test_reroll_changes_offer_eventually() -> void:
	EconomyManager.add_gold(0, 1000)
	var initial: Array[StringName] = _offer_ids(0)
	var changed: bool = false
	for _roll: int in 5:
		GameManager.submit_command(RerollShopCommand.new(0))
		changed = changed or _offer_ids(0) != initial
	assert_true(changed, "el reroll renueva la oferta")


func test_reroll_cost_decays_back_to_base() -> void:
	EconomyManager.add_gold(0, 1000)
	GameManager.submit_command(RerollShopCommand.new(0))
	GameManager.submit_command(RerollShopCommand.new(0))
	assert_eq(draft.get_reroll_cost(0), 16, "10 + 3 + 3")
	draft.simulate_step(9.9)
	assert_eq(draft.get_reroll_cost(0), 16, "sin rebaja antes de 10 s")
	draft.simulate_step(0.2)
	assert_eq(draft.get_reroll_cost(0), 15, "-1 a los 10 s")
	for _step: int in 60 * 60:
		draft.simulate_step(STEP)
	assert_eq(draft.get_reroll_cost(0), 10, "vuelve al base y no baja de ahí")


func test_reroll_cost_is_per_player() -> void:
	GameManager.submit_command(RerollShopCommand.new(0))
	assert_eq(draft.get_reroll_cost(1), 10, "el reroll del player 0 no afecta al rival")


# --- Jugar cartas --------------------------------------------------------------

func test_play_structure_card_on_plot() -> void:
	EconomyManager.add_gold(0, 200)
	draft.force_offer(0, [&"card_farm", &"card_tower", &"card_soldiers"] as Array[StringName])
	var chosen: Array[StringName] = []
	var listener: Callable = func(_pid: int, carta: CardData) -> void: chosen.append(carta.id)
	EventBus.carta_elegida.connect(listener)
	assert_true(_play(0, START_SLOT), "jugar Farm en el slot 16")
	EventBus.carta_elegida.disconnect(listener)
	assert_eq(_gold(), 220 - 50, "cobra el coste de la carta")
	assert_eq(grid0.get_structure_at(START_SLOT).data.id, &"farm", "Farm construida")
	assert_eq(chosen, [&"card_farm"] as Array[StringName], "carta_elegida")
	assert_eq(_offer_ids(0).size(), 3, "la tienda se renueva con 3 cartas")


func test_play_structure_by_drop_on_plot() -> void:
	EconomyManager.add_gold(0, 200)
	draft.force_offer(0, [&"card_farm", &"card_tower", &"card_soldiers"] as Array[StringName])
	var plot_center: Vector2 = grid0.to_global(grid0.get_plot_rect(4).get_center())
	input.play_card_at(0, GameManager.database.get_card(&"card_farm"), plot_center)
	assert_true(grid0.get_structure_at(16) != null, "soltar sobre el plot construye en su primer slot libre")


func test_structure_drop_outside_plot_rejected() -> void:
	EconomyManager.add_gold(0, 200)
	draft.force_offer(0, [&"card_farm", &"card_tower", &"card_soldiers"] as Array[StringName])
	input.play_card_at(0, GameManager.database.get_card(&"card_farm"), Vector2(540.0, 1500.0))
	input.play_card_at(0, GameManager.database.get_card(&"card_farm"), grid0.get_slot_world_position(0))
	assert_eq(_gold(), 220, "fuera del grid o en plot bloqueado: no se cobra")
	assert_eq(_offer_ids(0)[0], &"card_farm", "la carta sigue en la tienda")


func test_play_unit_card_in_own_half() -> void:
	EconomyManager.add_gold(0, 200)
	draft.force_offer(0, [&"card_soldiers", &"card_farm", &"card_tower"] as Array[StringName])
	assert_true(_play(0, -1, Vector2(540.0, 2000.0)), "3 soldiers en mi mitad")
	assert_eq(lane.get_alive_count(0), 3, "aparecen 3 soldiers")
	assert_eq(_gold(), 220 - 30, "cobra 30")


func test_unit_card_in_enemy_half_rejected() -> void:
	EconomyManager.add_gold(0, 200)
	draft.force_offer(0, [&"card_soldiers", &"card_farm", &"card_tower"] as Array[StringName])
	assert_false(_play(0, -1, Vector2(540.0, 1200.0)), "mitad rival")
	assert_eq(lane.get_alive_count(0), 0, "sin unidades")
	assert_eq(_gold(), 220, "sin cobro")


func test_cannot_play_unaffordable_card() -> void:
	draft.force_offer(0, [&"card_church", &"card_farm", &"card_tower"] as Array[StringName])
	assert_false(_play(0, START_SLOT), "Church (80) con 20 de oro")
	assert_true(grid0.get_state().is_slot_free(START_SLOT), "no se construye")


func test_stale_offer_rejected() -> void:
	EconomyManager.add_gold(0, 200)
	draft.force_offer(0, [&"card_farm", &"card_tower", &"card_soldiers"] as Array[StringName])
	var stale: PlayCardCommand = PlayCardCommand.new(0, 0, &"card_church", START_SLOT)
	assert_false(GameManager.submit_command(stale), "la carta no coincide con la oferta actual")


func test_player_cannot_play_rival_shop() -> void:
	EconomyManager.add_gold(1, 200)
	var command: PlayCardCommand = PlayCardCommand.new(1, 0, draft.get_offer_card_id(1, 0), START_SLOT, Vector2(540.0, 1200.0))
	assert_false(GameManager.submit_command(command), "LOCAL_PLAYER no juega la tienda rival")


func test_build_command_is_debug_only() -> void:
	EconomyManager.add_gold(0, 200)
	assert_false(GameManager.submit_command(BuildCommand.new(0, &"card_farm", START_SLOT)), "sin tienda no se construye")
	assert_true(GameManager.submit_command(BuildCommand.new(0, &"card_farm", START_SLOT, GameCommand.Source.DEBUG)), "debug sí")


# --- Martillo ------------------------------------------------------------------

func test_hammer_sells_tapped_structure() -> void:
	EconomyManager.add_gold(0, 200)
	GameManager.submit_command(BuildCommand.new(0, &"card_farm", START_SLOT, GameCommand.Source.DEBUG))
	var gold_before: int = _gold()
	input.set_hammer_mode(true)
	input.handle_tap(grid0.get_slot_world_position(START_SLOT))
	assert_true(grid0.get_state().is_slot_free(START_SLOT), "vendida")
	assert_eq(_gold(), gold_before + 25, "devuelve la mitad")
	assert_false(input.hammer_mode, "el martillo se desactiva tras vender")


func test_hammer_on_empty_slot_does_nothing() -> void:
	input.set_hammer_mode(true)
	input.handle_tap(grid0.get_slot_world_position(17))
	assert_eq(_gold(), 20, "sin cambios")
	assert_true(input.hammer_mode, "sigue activo para elegir otra estructura")
	input.set_hammer_mode(false)


func test_shop_in_snapshot() -> void:
	var players: Array = GameManager.match_state.to_dict()["players"]
	var shop: Dictionary = (players[0] as Dictionary)["shop"]
	assert_eq((shop["offer"] as Array).size(), 3, "oferta en el snapshot")
	assert_eq(shop["reroll_cost"], 10, "coste de reroll en el snapshot")
