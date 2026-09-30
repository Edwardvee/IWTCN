extends TestSuite
## Cartas de sabotaje (congelar, bloquear tienda, reroll forzado, robo, silencio) y el derrumbe
## del castillo.

const STEP: float = 1.0 / 60.0
const DEBUG: GameCommand.Source = GameCommand.Source.DEBUG
const START_SLOT: int = 16

var processor: CommandProcessor = null
var draft: DraftManager = null
var grid0: GridManager = null
var grid1: GridManager = null
var lane: LaneManager = null


func before_each() -> void:
	if processor == null:
		_build_fixture()
	GameManager.register_command_processor(processor)
	GameManager.match_mods = []
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 7171)
	EconomyManager.add_gold(0, 1000)
	EconomyManager.add_gold(1, 1000)


func after_all() -> void:
	GameManager.register_command_processor(null)
	lane.clear_units()
	for node: Node in [processor, draft, grid0, grid1, lane]:
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


func _card(kind: CardData.SabotageKind) -> CardData:
	for card: CardData in GameManager.database.cards:
		if card.card_type == CardData.CardType.SABOTAGE and card.sabotage_kind == kind:
			return card
	return null


func _rival_farm() -> void:
	assert_true(GameManager.submit_command(BuildCommand.new(1, &"card_farm", START_SLOT, DEBUG)), "el rival construye una granja")


func _now() -> float:
	return GameManager.match_state.match_time


# --- Catálogo ------------------------------------------------------------------

func test_five_sabotage_cards_with_art_and_translations() -> void:
	var kinds: Dictionary = {}
	for card: CardData in GameManager.database.cards:
		if card.card_type != CardData.CardType.SABOTAGE:
			continue
		kinds[card.sabotage_kind] = true
		assert_true(card.icon != null, "%s tiene icono" % card.id)
		assert_true(card.get_validation_errors().is_empty(), "%s es válida" % card.id)
		assert_true(TranslationTables.EN.has(card.display_name) and TranslationTables.EN.has(card.description), "%s está traducida" % card.id)
	assert_eq(kinds.size(), 5, "cinco tipos de sabotaje distintos")
	assert_true(TranslationTables.EN.has("SABOTAJE"), "la etiqueta del tipo está traducida")
	assert_true(draft.enabled_card_types.has(CardData.CardType.SABOTAGE), "pueden salir en la tienda")


# --- Congelar ----------------------------------------------------------------------

func test_freeze_needs_a_structure_and_freezes_it_for_five_seconds() -> void:
	var freeze: CardData = _card(CardData.SabotageKind.FREEZE_STRUCTURE)
	assert_false(Sabotage.can_apply(freeze, 0, draft) == "", "sin estructuras rivales no se puede lanzar")
	_rival_farm()
	assert_eq(Sabotage.can_apply(freeze, 0, draft), "", "con una estructura sí")
	assert_true(Sabotage.apply(freeze, 0, draft), "se aplica")
	var rival: PlayerState = GameManager.get_player_state(1)
	assert_true(rival.is_slot_frozen(START_SLOT, _now()), "la granja queda congelada")
	assert_true(rival.is_slot_frozen(START_SLOT, _now() + 4.5), "sigue helada a los 4,5 s")
	assert_false(rival.is_slot_frozen(START_SLOT, _now() + 5.1), "y se descongela pasados 5 s")
	assert_false(Sabotage.can_apply(freeze, 0, draft) == "", "ya no queda nada que congelar")
	assert_eq(GameManager.get_player_state(0).frozen_slots.size(), 0, "el atacante no se congela")


func test_frozen_structure_stops_producing_then_resumes() -> void:
	_rival_farm()
	var farm: StructureBase = grid1.get_structure_at(START_SLOT)
	var interval: float = farm.get_production_interval()
	GameManager.get_player_state(1).frozen_slots[START_SLOT] = _now() + 5.0
	var before: int = EconomyManager.get_gold(1)
	for _step: int in roundi(interval * 2.5 / STEP):
		grid1.simulate_step(STEP)
	assert_eq(EconomyManager.get_gold(1), before, "congelada no produce")
	assert_eq(farm.production_timer, 0.0, "ni avanza su barra")
	GameManager.match_state.match_time += 6.0
	for _step: int in roundi(interval * 1.2 / STEP):
		grid1.simulate_step(STEP)
	assert_true(EconomyManager.get_gold(1) > before, "descongelada vuelve a producir")


func test_frozen_structure_looks_frozen() -> void:
	_rival_farm()
	var farm: StructureBase = grid1.get_structure_at(START_SLOT)
	GameManager.get_player_state(1).frozen_slots[START_SLOT] = _now() + 5.0
	grid1._update_frozen_visuals()
	assert_true(farm.frozen, "marcada como congelada")
	assert_true(farm.modulate != Color.WHITE, "con tinte helado")
	GameManager.match_state.match_time += 6.0
	grid1._update_frozen_visuals()
	assert_false(farm.frozen, "se deshiela sola")
	assert_eq(farm.modulate, Color.WHITE, "y recupera el color")


# --- Bloquear tienda -----------------------------------------------------------------

func test_block_locks_one_shop_slot_and_purchases_are_refused_until_it_ends() -> void:
	var block: CardData = _card(CardData.SabotageKind.BLOCK_SHOP_SLOT)
	assert_true(Sabotage.apply(block, 0, draft), "se aplica")
	var shop: ShopState = GameManager.get_player_state(1).shop
	var locked: Array[int] = []
	for index: int in shop.offer.size():
		if shop.is_blocked(index, _now()):
			locked.append(index)
	assert_eq(locked.size(), 1, "un hueco bloqueado")
	var index: int = locked[0]
	var card_id: StringName = shop.offer[index]
	assert_false(GameManager.submit_command(PlayCardCommand.new(1, index, card_id, START_SLOT, Vector2(540.0, 500.0), DEBUG)), "no se puede comprar la carta bloqueada")
	assert_true(draft.get_block_left(1, index) > 4.0, "faltan unos 5 s")
	shop.blocked_until[index] = _now() - 1.0
	assert_eq(draft.get_block_left(1, index), 0.0, "pasado el tiempo queda libre")


func test_block_survives_a_reroll() -> void:
	draft.force_offer(1, [&"card_farm", &"card_tower", &"card_soldiers"])
	GameManager.get_player_state(1).shop.block(1, _now() + 5.0)
	draft.apply_reroll(1)
	assert_true(GameManager.get_player_state(1).shop.is_blocked(1, _now()), "el bloqueo es del hueco, no de la carta")


# --- Reroll forzado, robo y silencio ---------------------------------------------------

func test_forced_reroll_renews_the_rival_shop_for_free() -> void:
	var counter: Array[int] = [0]
	var listener: Callable = func(player_id: int, _cards: Array[CardData]) -> void:
		if player_id == 1:
			counter[0] += 1
	EventBus.draft_ofrecido.connect(listener)
	var cost_before: int = draft.get_reroll_cost(1)
	var gold_before: int = EconomyManager.get_gold(1)
	assert_true(Sabotage.apply(_card(CardData.SabotageKind.FORCE_REROLL), 0, draft), "se aplica")
	EventBus.draft_ofrecido.disconnect(listener)
	assert_eq(counter[0], 1, "su tienda se renueva")
	assert_eq(draft.get_reroll_cost(1), cost_before, "sin subirle el precio del reroll")
	assert_eq(EconomyManager.get_gold(1), gold_before, "ni gastarle oro")


func test_steal_moves_gold_and_never_more_than_they_have() -> void:
	var steal: CardData = _card(CardData.SabotageKind.STEAL_GOLD)
	var mine: int = EconomyManager.get_gold(0)
	var theirs: int = EconomyManager.get_gold(1)
	assert_true(Sabotage.apply(steal, 0, draft), "se aplica")
	assert_eq(EconomyManager.get_gold(1), theirs - 25, "el rival pierde 25")
	assert_eq(EconomyManager.get_gold(0), mine + 25, "y tú los ganas")
	EconomyManager.spend_gold(1, EconomyManager.get_gold(1) - 10)
	var mine_now: int = EconomyManager.get_gold(0)
	assert_true(Sabotage.apply(steal, 0, draft), "con 10 de oro")
	assert_eq(EconomyManager.get_gold(1), 0, "solo se lleva lo que tiene")
	assert_eq(EconomyManager.get_gold(0), mine_now + 10, "10 de oro")
	assert_false(Sabotage.can_apply(steal, 0, draft) == "", "sin oro no hay nada que robar")


func test_silence_delays_rival_spells_only() -> void:
	var rival: PlayerState = GameManager.get_player_state(1)
	assert_true(Sabotage.apply(_card(CardData.SabotageKind.SILENCE_SPELLS), 0, draft), "se aplica")
	for spell: SpellData in GameManager.database.spells:
		assert_true(rival.get_spell_ready_at(spell.id) >= _now() + 7.9, "%s bloqueado 8 s" % spell.id)
		assert_eq(GameManager.get_player_state(0).get_spell_ready_at(spell.id), 0.0, "los tuyos siguen listos")


# --- Compra de la carta ----------------------------------------------------------------

func test_buying_a_sabotage_card_charges_gold_and_hits_the_rival() -> void:
	var steal: CardData = _card(CardData.SabotageKind.STEAL_GOLD)
	draft.force_offer(0, [steal.id, &"card_farm", &"card_tower"])
	var mine: int = EconomyManager.get_gold(0)
	var theirs: int = EconomyManager.get_gold(1)
	assert_true(GameManager.submit_command(PlayCardCommand.new(0, 0, steal.id, -1, Vector2(540.0, 2000.0))), "se compra soltándola en cualquier sitio")
	assert_eq(EconomyManager.get_gold(0), mine - steal.cost + 25, "paga la carta y cobra el robo")
	assert_eq(EconomyManager.get_gold(1), theirs - 25, "el rival paga")
	var freeze: CardData = _card(CardData.SabotageKind.FREEZE_STRUCTURE)
	draft.force_offer(0, [freeze.id, &"card_farm", &"card_tower"])
	assert_false(GameManager.submit_command(PlayCardCommand.new(0, 0, freeze.id, -1, Vector2.ZERO)), "sin estructuras rivales se rechaza")


func test_sabotage_state_travels_in_the_snapshot() -> void:
	_rival_farm()
	GameManager.get_player_state(1).frozen_slots[START_SLOT] = 12.5
	GameManager.get_player_state(1).shop.block(2, 9.0)
	var players: Array = GameManager.match_state.to_dict()["players"]
	assert_eq((players[1]["frozen"] as Dictionary)[str(START_SLOT)], 12.5, "congelaciones")
	assert_eq((players[1]["shop"]["blocked"] as Array)[2], 9.0, "bloqueos de la tienda")


# --- Interfaz y derrumbe ------------------------------------------------------------------

func test_card_view_covers_a_blocked_card_and_refuses_the_gesture() -> void:
	var view: CardView = CardView.new()
	get_root().add_child(view)
	view.set_card(0, _card(CardData.SabotageKind.STEAL_GOLD))
	assert_false(view.is_blocked(), "libre al principio")
	view.set_blocked(3.2)
	assert_true(view.is_blocked(), "cubierta")
	assert_eq(view._block_label.text, "4", "cuenta atrás redondeada hacia arriba")
	view.set_blocked(0.0)
	assert_false(view.is_blocked(), "se descubre")
	assert_eq(CardView.type_color(CardData.CardType.SABOTAGE), Color("ef5350"), "borde rojo")
	view.queue_free()


func test_castle_collapse_plays_once_and_resets_with_a_new_match() -> void:
	var castle: Castle = Castle.new()
	castle.owner_id = 1
	get_root().add_child(castle)
	var children_before: int = castle.get_child_count()
	castle._on_castillo_danado(1, 0.0, 100.0)
	assert_true(castle._collapsed, "se derrumba")
	assert_eq(castle.get_child_count(), children_before + 2, "escombros y polvo")
	castle._on_castillo_danado(1, 0.0, 100.0)
	assert_eq(castle.get_child_count(), children_before + 2, "solo una vez")
	castle._on_partida_iniciada(0, 1)
	assert_false(castle._collapsed, "una partida nueva lo restaura")
	castle.queue_free()


func test_ai_values_sabotage() -> void:
	var strategy: RuleBasedStrategy = RuleBasedStrategy.new()
	assert_true(strategy.sabotage_score > 0, "la IA les da valor")
