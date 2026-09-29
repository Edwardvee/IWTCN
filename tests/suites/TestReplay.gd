extends TestSuite
## Repetición, espectador local, oferta inicial con Farm y feedback visual.

const STEP: float = 1.0 / 60.0
const TEST_DIRECTORY: String = "user://test_replays"

var processor: CommandProcessor = null
var draft: DraftManager = null
var lane: LaneManager = null
var grid0: GridManager = null
var grid1: GridManager = null
var replicator: StateReplicator = null
var recorder: ReplayRecorder = null
var floating: FloatingTextLayer = null


func before_each() -> void:
	if processor == null:
		_build_fixture()
	ReplayData.directory = TEST_DIRECTORY
	GameManager.suppress_effects = false
	GameManager.register_command_processor(processor)
	recorder.enabled = true
	recorder.last_saved_path = ""
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 4242)


func after_all() -> void:
	_clear_test_directory()
	GameManager.suppress_effects = false
	GameManager.register_command_processor(null)
	lane.clear_units()
	for node: Node in [processor, draft, lane, grid0, grid1, replicator, recorder, floating]:
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
	replicator = StateReplicator.new()
	recorder = ReplayRecorder.new()
	floating = FloatingTextLayer.new()
	for node: Node in [processor, draft, lane, grid0, grid1, replicator, recorder, floating]:
		get_root().add_child(node)
	for grid: GridManager in [grid0, grid1]:
		grid.lane = lane
		processor.register_grid(grid)
	processor.register_lane(lane)
	processor.register_draft(draft)
	replicator.setup(lane, [grid0, grid1])
	recorder.replicator = replicator
	floating.setup([grid0, grid1])


func _clear_test_directory() -> void:
	for file_name: String in DirAccess.get_files_at(TEST_DIRECTORY):
		DirAccess.remove_absolute("%s/%s" % [TEST_DIRECTORY, file_name])
	DirAccess.remove_absolute(TEST_DIRECTORY)


## Avanza la simulación completa `seconds`, incluida la grabación.
func _simulate(seconds: float) -> void:
	for _step: int in roundi(seconds / STEP):
		if not GameManager.is_match_running():
			return
		GameManager.match_state.match_time += STEP
		EconomyManager.simulate_step(STEP)
		draft.simulate_step(STEP)
		grid0.simulate_step(STEP)
		grid1.simulate_step(STEP)
		lane.simulate_step(STEP)
		recorder._physics_process(STEP)


func _record_scripted_match() -> ReplayData:
	EconomyManager.add_gold(0, 300)
	GameManager.submit_command(BuildCommand.new(0, &"card_farm", 16, GameCommand.Source.DEBUG))
	GameManager.submit_command(BuildCommand.new(0, &"card_soldier_barracks", 18, GameCommand.Source.DEBUG))
	lane.spawn_group_at(GameManager.database.get_unit(&"soldier"), 0, 3, Vector2(540.0, 2000.0))
	lane.spawn_group_at(GameManager.database.get_unit(&"archer"), 1, 2, Vector2(540.0, 1000.0))
	_simulate(12.0)
	GameManager.end_match(MatchTypes.PLAYER_BOTTOM)
	return ReplayData.load_from(recorder.last_saved_path)


# --- Oferta inicial con Farm ----------------------------------------------------------

func test_starting_offer_always_contains_farm() -> void:
	for seed_value: int in range(1, 41):
		GameManager.start_match(MatchTypes.GameMode.VS_AI, seed_value)
		for player_id: int in MatchTypes.PLAYER_COUNT:
			var offer: Array[StringName] = GameManager.get_player_state(player_id).shop.offer
			assert_true(offer.has(&"card_farm"), "semilla %d, jugador %d: la oferta inicial incluye Farm (%s)" % [seed_value, player_id, str(offer)])
			assert_eq(offer.size(), 3, "la oferta sigue teniendo 3 cartas")
			var unique: Dictionary = {}
			for card_id: StringName in offer:
				unique[card_id] = true
			assert_eq(unique.size(), 3, "sin cartas repetidas")


func test_farm_guarantee_can_be_disabled() -> void:
	var rules: GameRules = GameManager.get_rules()
	rules.guarantee_starting_farm = false
	var without_farm: int = 0
	for seed_value: int in range(1, 41):
		GameManager.start_match(MatchTypes.GameMode.VS_AI, seed_value)
		if not GameManager.get_player_state(0).shop.offer.has(&"card_farm"):
			without_farm += 1
	rules.guarantee_starting_farm = true
	assert_true(without_farm > 0, "sin la regla, a veces no sale Farm")


func test_farm_only_guaranteed_on_first_offer() -> void:
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 7)
	var farms_seen: int = 0
	for _reroll: int in 30:
		EconomyManager.add_gold(0, 100)
		GameManager.submit_command(RerollShopCommand.new(0))
		if GameManager.get_player_state(0).shop.offer.has(&"card_farm"):
			farms_seen += 1
	assert_true(farms_seen < 30, "los rerolls posteriores no fuerzan Farm")


# --- Modo espectador -------------------------------------------------------------------

func test_spectate_blocks_local_player_commands() -> void:
	GameManager.start_match(MatchTypes.GameMode.SPECTATE, 11)
	EconomyManager.add_gold(0, 100)
	assert_false(GameManager.submit_command(RerollShopCommand.new(0, GameCommand.Source.LOCAL_PLAYER)), "el espectador no juega")


func test_spectate_allows_ai_on_both_seats() -> void:
	GameManager.start_match(MatchTypes.GameMode.SPECTATE, 11)
	for player_id: int in MatchTypes.PLAYER_COUNT:
		EconomyManager.add_gold(player_id, 100)
		assert_true(GameManager.submit_command(RerollShopCommand.new(player_id, GameCommand.Source.AI)), "la IA controla el asiento %d" % player_id)


func test_vs_ai_still_blocks_ai_on_local_seat() -> void:
	EconomyManager.add_gold(0, 100)
	assert_false(GameManager.submit_command(RerollShopCommand.new(0, GameCommand.Source.AI)), "en VS IA la IA no controla al jugador")


func test_replay_mode_has_no_authority() -> void:
	GameManager.start_match(MatchTypes.GameMode.REPLAY, 5)
	assert_false(GameManager.is_authority(), "una repetición nunca simula")
	assert_true(GameManager.is_watching(), "es un modo de solo mirar")
	EconomyManager.add_gold(0, 50)
	assert_eq(EconomyManager.get_gold(0), 0, "ni siquiera el oro se toca (%d)" % EconomyManager.get_gold(0))


# --- Grabación y reproducción --------------------------------------------------------------

func test_recorder_saves_replay_when_match_ends() -> void:
	var data: ReplayData = _record_scripted_match()
	assert_true(data != null, "la repetición se guarda y se puede cargar")
	if data == null:
		return
	assert_true(data.frames.size() >= 100, "≈10 snapshots por segundo (%d)" % data.frames.size())
	assert_eq(data.get_seed(), 4242, "guarda la semilla")
	assert_eq(data.get_winner(), MatchTypes.PLAYER_BOTTOM, "guarda el ganador")
	assert_true(data.get_duration() >= 11.9, "duración ≈ 12 s (%.1f)" % data.get_duration())
	assert_false((data.frames[0]["s"]["match"] as Dictionary).has("random"), "no guarda el estado del azar")


func test_recorder_disabled_saves_nothing() -> void:
	recorder.enabled = false
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 99)
	_simulate(2.0)
	GameManager.end_match(0)
	assert_eq(recorder.last_saved_path, "", "sin grabador activo no hay archivo")


func test_replay_playback_reproduces_recorded_state() -> void:
	var data: ReplayData = _record_scripted_match()
	assert_true(data != null, "hay repetición")
	if data == null:
		return
	# Estado autoritativo al terminar la partida: lo que la repetición debe reproducir.
	var expected_gold: Dictionary = {}
	var expected_grids: Dictionary = {}
	for player_state: PlayerState in GameManager.match_state.players:
		expected_gold[player_state.player_id] = player_state.gold
		expected_grids[player_state.player_id] = str(player_state.grid.to_dict())
	var player: ReplayPlayer = ReplayPlayer.new()
	get_root().add_child(player)
	player.start(data, replicator)
	assert_eq(GameManager.game_mode, MatchTypes.GameMode.REPLAY, "modo repetición")
	assert_eq(lane.get_alive_count(0), 0, "arranca sin unidades")
	var guard: int = 0
	while not player.is_finished() and guard < 5000:
		player._physics_process(STEP)
		guard += 1
	assert_true(player.is_finished(), "llega al final")
	assert_eq(GameManager.match_phase, MatchTypes.MatchPhase.ENDED, "la partida acaba")
	assert_eq(GameManager.match_state.winner_player_id, MatchTypes.PLAYER_BOTTOM, "muestra el ganador grabado")
	for player_id: int in expected_gold:
		var replayed: PlayerState = GameManager.get_player_state(player_id)
		assert_eq(replayed.gold, expected_gold[player_id], "oro final igual (jugador %d)" % player_id)
		assert_eq(str(replayed.grid.to_dict()), expected_grids[player_id], "cuadrícula final igual (jugador %d)" % player_id)
	assert_true(GameManager.get_player_state(0).grid.get_occupied_slots().size() >= 2, "las estructuras construidas se reproducen")
	player.queue_free()


func test_replay_seek_backwards_and_forwards() -> void:
	var data: ReplayData = _record_scripted_match()
	if data == null:
		assert_true(false, "hay repetición")
		return
	var player: ReplayPlayer = ReplayPlayer.new()
	get_root().add_child(player)
	player.start(data, replicator)
	player.playing = false
	player.seek(8.0)
	assert_true(absf(GameManager.match_state.match_time - 8.0) < 0.2, "salta a 8 s (%.2f)" % GameManager.match_state.match_time)
	assert_false(player.is_finished(), "aún no ha terminado")
	var units_at_8: int = lane.get_alive_units().size()
	player.seek(2.0)
	assert_true(absf(GameManager.match_state.match_time - 2.0) < 0.2, "salta hacia atrás a 2 s (%.2f)" % GameManager.match_state.match_time)
	player.seek(8.0)
	assert_eq(lane.get_alive_units().size(), units_at_8, "volver al mismo instante da el mismo ejército")
	player.seek(9999.0)
	assert_true(player.is_finished(), "saltar al final termina la repetición")
	player.seek(0.0)
	assert_false(player.is_finished(), "volver al principio la reabre")
	assert_false(GameManager.suppress_effects, "los efectos se reactivan tras saltar")
	player.queue_free()


func test_replay_list_and_prune() -> void:
	_clear_test_directory()
	for index: int in ReplayData.MAX_SAVED + 3:
		var data: ReplayData = ReplayData.new({"seed": index, "winner": 0})
		data.add_frame(0.0, {"match": {}, "lane": {}})
		data.add_frame(1.0, {"match": {}, "lane": {}})
		data.save("replay_2026-01-01_00-00-%02d" % index)
	var listed: Array[Dictionary] = ReplayData.list_replays()
	assert_eq(listed.size(), ReplayData.MAX_SAVED, "solo se conservan las %d más recientes" % ReplayData.MAX_SAVED)
	assert_eq(int(listed[0]["seed"]), ReplayData.MAX_SAVED + 2, "la más reciente primero")
	assert_true(ReplayData.load_from(str(listed[0]["path"])) != null, "se puede volver a cargar")
	assert_true(ReplayData.load_from("user://no_existe.iwr") == null, "archivo inexistente = null")


# --- Números flotantes ------------------------------------------------------------------------

func test_damage_creates_floating_number() -> void:
	var unit: UnitBase = lane.spawn_unit(GameManager.database.get_unit(&"soldier"), 0, Vector2(540.0, 2000.0))
	var before: int = floating.get_entry_count()
	unit.receive_damage(40.0, 0)
	assert_eq(floating.get_entry_count(), before + 1, "un número por golpe")


func test_heal_creates_floating_number() -> void:
	var unit: UnitBase = lane.spawn_unit(GameManager.database.get_unit(&"soldier"), 0, Vector2(540.0, 2000.0))
	unit.receive_damage(100.0, 0)
	var before: int = floating.get_entry_count()
	unit.receive_heal(30.0, 0)
	assert_eq(floating.get_entry_count(), before + 1, "curar también muestra número")


func test_floating_numbers_silenced_while_seeking() -> void:
	var unit: UnitBase = lane.spawn_unit(GameManager.database.get_unit(&"soldier"), 0, Vector2(540.0, 2000.0))
	var before: int = floating.get_entry_count()
	GameManager.suppress_effects = true
	unit.receive_damage(40.0, 0)
	GameManager.suppress_effects = false
	assert_eq(floating.get_entry_count(), before, "sin números durante el salto")


func test_castle_damage_and_building_show_feedback() -> void:
	var before: int = floating.get_entry_count()
	lane.damage_castle(1, 200.0)
	EconomyManager.add_gold(0, 200)
	GameManager.submit_command(BuildCommand.new(0, &"card_farm", 16, GameCommand.Source.DEBUG))
	assert_true(floating.get_entry_count() >= before + 2, "daño al castillo y construcción muestran aviso (%d → %d)" % [before, floating.get_entry_count()])


func test_floating_entries_expire() -> void:
	floating.add_text(Vector2.ZERO, "x", Color.WHITE, 20, 0.5)
	assert_true(floating.get_entry_count() > 0, "hay una entrada")
	for _frame: int in 40:
		floating._process(0.05)
	assert_eq(floating.get_entry_count(), 0, "las entradas caducan")


# --- Ayuda visual al construir --------------------------------------------------------------------

func test_build_hints_mark_valid_slots() -> void:
	var farm: StructureData = GameManager.database.get_structure(&"farm")
	grid0.show_build_hints(farm, true)
	var valid_slots: int = 0
	for slot_index: int in GridState.SLOT_COUNT:
		if grid0.get_slot_node(slot_index).get_hint() == BuildingSlot.Hint.VALID:
			valid_slots += 1
	assert_eq(valid_slots, 4, "los 4 slots del plot inicial son destino válido")
	grid0.show_build_hints(farm, false)
	for slot_index: int in GridState.SLOT_COUNT:
		assert_eq(grid0.get_slot_node(slot_index).get_hint(), BuildingSlot.Hint.NONE, "sin oro no se marca ninguno")
	grid0.clear_build_hints()
