extends TestSuite
## Fase 13: IA basada en reglas que juega SOLO mediante comandos validados.

const STEP: float = 1.0 / 60.0
const AI_PLAYER: int = 1

var processor: CommandProcessor = null
var draft: DraftManager = null
var lane: LaneManager = null
var grid0: GridManager = null
var grid1: GridManager = null
var ai: AIController = null
var ai_rejections: PackedStringArray = PackedStringArray()


func before_each() -> void:
	if processor == null:
		_build_fixture()
	GameManager.register_command_processor(processor)
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 1313)
	ai.enabled = true
	ai_rejections.clear()


func after_all() -> void:
	EventBus.comando_rechazado.disconnect(_on_rejected)
	GameManager.register_command_processor(null)
	lane.clear_units()
	for node: Node in [processor, draft, lane, grid0, grid1, ai]:
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
	ai = AIController.new()
	for node: Node in [processor, draft, lane, grid0, grid1, ai]:
		get_root().add_child(node)
	for grid: GridManager in [grid0, grid1]:
		grid.lane = lane
		processor.register_grid(grid)
	processor.register_lane(lane)
	processor.register_draft(draft)
	ai.setup(AI_PLAYER, draft, grid1, lane)
	EventBus.comando_rechazado.connect(_on_rejected)


func _on_rejected(player_id: int, command_type: StringName, reason: String) -> void:
	if player_id == AI_PLAYER:
		ai_rejections.append("%s: %s" % [command_type, reason])


func _simulate(seconds: float) -> void:
	for _step: int in roundi(seconds / STEP):
		if not GameManager.is_match_running():
			return
		EconomyManager.simulate_step(STEP)
		draft.simulate_step(STEP)
		grid0.simulate_step(STEP)
		grid1.simulate_step(STEP)
		lane.simulate_step(STEP)
		ai.simulate_step(STEP)


func _offer(ids: Array[StringName]) -> void:
	draft.force_offer(AI_PLAYER, ids)


func test_builds_farm_when_affordable() -> void:
	EconomyManager.add_gold(AI_PLAYER, 100)
	_offer([&"card_farm", &"card_tower", &"card_soldiers"] as Array[StringName])
	assert_true(ai.think(), "la IA actúa")
	assert_eq(grid1.get_structure_at(18).data.id, &"farm", "Farm en la fila trasera")
	assert_eq(EconomyManager.get_gold(AI_PLAYER), 70, "paga el precio de la carta")


func test_waits_when_poor() -> void:
	_offer([&"card_farm", &"card_church", &"card_tower"] as Array[StringName])
	assert_false(ai.think(), "con 20 de oro espera")
	assert_eq(EconomyManager.get_gold(AI_PLAYER), 20, "no gasta")
	assert_eq(draft.get_offer_card_id(AI_PLAYER, 0), &"card_farm", "no hace reroll de una buena oferta")


func test_defends_its_half() -> void:
	EconomyManager.add_gold(AI_PLAYER, 200)
	lane.spawn_group_at(GameManager.database.get_unit(&"soldier"), 0, 3, Vector2(540.0, 1400.0))
	_offer([&"card_soldiers", &"card_farm", &"card_tower"] as Array[StringName])
	assert_true(ai.think(), "responde a la amenaza")
	assert_eq(lane.get_alive_count(AI_PLAYER), 3, "despliega 3 soldiers")
	for unit: UnitBase in lane.get_alive_units():
		if unit.team == AI_PLAYER:
			assert_true(lane.is_valid_deploy_position(AI_PLAYER, unit.global_position), "en su propia mitad")


func test_unlocks_plot_when_full() -> void:
	EconomyManager.add_gold(AI_PLAYER, 1000)
	for card_id: StringName in [&"card_farm", &"card_farm", &"card_soldier_barracks", &"card_archer_barracks"]:
		GameManager.submit_command(BuildCommand.new(AI_PLAYER, card_id, ai.find_build_slot(false), GameCommand.Source.DEBUG))
	assert_eq(ai.find_build_slot(false), -1, "plot inicial lleno")
	assert_true(ai.think(), "la IA actúa")
	assert_true(grid1.get_state().is_plot_unlocked(5), "compra el plot más barato (10)")


func test_rerolls_useless_offer() -> void:
	EconomyManager.add_gold(AI_PLAYER, 200)
	_offer([&"card_buff_armor", &"card_buff_max_hp", &"card_buff_move_speed"] as Array[StringName])
	assert_true(ai.think(), "la IA actúa")
	assert_eq(GameManager.get_player_state(AI_PLAYER).shop.reroll_count, 1, "hace reroll")


func test_tower_goes_to_front_row() -> void:
	EconomyManager.add_gold(AI_PLAYER, 200)
	GameManager.submit_command(UnlockPlotCommand.new(AI_PLAYER, 1, GameCommand.Source.DEBUG))
	lane.spawn_unit(GameManager.database.get_unit(&"soldier"), 0, Vector2(540.0, 1400.0))
	_offer([&"card_tower", &"card_buff_armor", &"card_buff_max_hp"] as Array[StringName])
	assert_true(ai.think(), "la IA actúa")
	var tower: StructureBase = grid1.get_structure_at(4)
	assert_true(tower != null and tower.data.id == &"tower", "Tower en la fila delantera del plot 1")


func test_ai_source_cannot_control_local_player() -> void:
	EconomyManager.add_gold(0, 200)
	var command: PlayCardCommand = PlayCardCommand.new(0, 0, draft.get_offer_card_id(0, 0), 16, Vector2(540.0, 2000.0), GameCommand.Source.AI)
	assert_false(GameManager.submit_command(command), "la IA no puede jugar por el jugador")


func test_disabled_ai_does_nothing() -> void:
	ai.enabled = false
	EconomyManager.add_gold(AI_PLAYER, 500)
	_simulate(10.0)
	assert_eq(grid1.get_state().get_occupied_slots().size(), 0, "IA desactivada: nada construido")


func test_ai_inactive_outside_vs_ai() -> void:
	GameManager.start_match(MatchTypes.GameMode.ONLINE, 1313)
	EconomyManager.add_gold(AI_PLAYER, 500)
	_simulate(5.0)
	assert_eq(grid1.get_state().get_occupied_slots().size(), 0, "en ONLINE la IA no juega")


func test_full_game_against_passive_player() -> void:
	_simulate(240.0)
	assert_true(ai_rejections.is_empty(), "todos sus comandos son válidos: %s" % ", ".join(ai_rejections))
	assert_true(grid1.get_state().get_occupied_slots().size() >= 4, "construye varias estructuras (%d)" % grid1.get_state().get_occupied_slots().size())
	var own_castle: float = GameManager.get_player_state(0).castle_hp
	assert_true(own_castle < 3000.0 or GameManager.match_state.winner_player_id == AI_PLAYER, "su ejército ataca el castillo del jugador (vida %.0f)" % own_castle)


func test_ai_is_deterministic() -> void:
	_simulate(90.0)
	var first: String = _snapshot_without_match_id()
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 1313)
	_simulate(90.0)
	assert_eq(_snapshot_without_match_id(), first, "misma semilla → misma partida de la IA")


## match_id es un contador de partidas: distinto en cada una por diseño.
func _snapshot_without_match_id() -> String:
	var snapshot: Dictionary = GameManager.match_state.to_dict()
	snapshot.erase("match_id")
	return str(snapshot)


# --- Dificultad ---------------------------------------------------------------------

func test_difficulty_levels_configure_the_ai() -> void:
	AIDifficulty.apply(ai, AIDifficulty.Level.NORMAL)
	assert_eq(ai.think_interval, 1.0, "normal: reacción de siempre")
	assert_eq(ai.income_multiplier, 1.0, "normal: sin ventaja de ingresos")
	AIDifficulty.apply(ai, AIDifficulty.Level.EASY)
	assert_true(ai.think_interval > 2.0 and ai.income_multiplier < 1.0, "fácil: reacciona despacio e ingresa menos")
	assert_true((ai.strategy as RuleBasedStrategy).idle_chance > 0.0, "fácil: a veces no hace nada")
	AIDifficulty.apply(ai, AIDifficulty.Level.HARD)
	assert_true(ai.think_interval < 1.0 and ai.income_multiplier > 1.0, "difícil: reacciona rápido e ingresa más")
	assert_eq((ai.strategy as RuleBasedStrategy).idle_chance, 0.0, "difícil: no se equivoca a propósito")
	AIDifficulty.apply(ai, AIDifficulty.Level.NORMAL)


func test_level_names_and_cycling() -> void:
	assert_eq(AIDifficulty.level_from_name(&"hard"), AIDifficulty.Level.HARD, "por nombre")
	assert_eq(AIDifficulty.level_from_name(&"nope"), -1, "nombre desconocido")
	assert_eq(AIDifficulty.next_level(AIDifficulty.Level.EASY), AIDifficulty.Level.NORMAL, "fácil → normal")
	assert_eq(AIDifficulty.next_level(AIDifficulty.Level.HARD), AIDifficulty.Level.EASY, "difícil → fácil (vuelve al principio)")
	AIDifficulty.apply_by_name(ai, &"rush")
	assert_eq(ai.income_multiplier, 1.0, "un estilo suelto no da ventaja")
	AIDifficulty.apply(ai, AIDifficulty.Level.NORMAL)


func test_income_multiplier_scales_income_with_remainder() -> void:
	ai.income_multiplier = 1.3
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 1313)
	var start: int = EconomyManager.get_gold(AI_PLAYER)
	for _cycle: int in 10:
		EconomyManager.add_income(AI_PLAYER, 3)
	# 10 × 3 × 1.3 = 39 exactos (los decimales se acumulan, no se pierden).
	assert_eq(EconomyManager.get_gold(AI_PLAYER) - start, 39, "10 ingresos de 3 con ×1.3")
	EconomyManager.add_income(0, 3)
	assert_eq(EconomyManager.get_gold(0), GameManager.get_rules().starting_gold + 3, "el jugador humano no tiene multiplicador")
	EconomyManager.add_gold(AI_PLAYER, 100)
	assert_eq(EconomyManager.get_gold(AI_PLAYER) - start, 139, "el oro normal (ventas, reembolsos) no se multiplica")
	ai.income_multiplier = 1.0
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 1313)


func test_easy_ai_wastes_turns_but_hard_does_not() -> void:
	var easy_actions: int = _count_actions(AIDifficulty.Level.EASY)
	var hard_actions: int = _count_actions(AIDifficulty.Level.HARD)
	AIDifficulty.apply(ai, AIDifficulty.Level.NORMAL)
	assert_true(easy_actions < hard_actions, "fácil actúa menos veces (%d) que difícil (%d)" % [easy_actions, hard_actions])


## Turnos de decisión con oro de sobra en los que la IA hace algo.
func _count_actions(level: AIDifficulty.Level) -> int:
	AIDifficulty.apply(ai, level)
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 4321)
	var acted: int = 0
	for _turn: int in 60:
		EconomyManager.add_gold(AI_PLAYER, 40)
		if ai.think():
			acted += 1
	return acted
