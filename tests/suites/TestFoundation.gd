extends TestSuite
## Fase 0: configuración del proyecto, autoloads, partida y reglas base del oro.

const TEST_SEED: int = 12345


func before_each() -> void:
	GameManager.start_match(MatchTypes.GameMode.VS_AI, TEST_SEED)


func test_autoloads_registered() -> void:
	var root: Window = get_root()
	assert_true(root.has_node("EventBus"), "Falta autoload EventBus")
	assert_true(root.has_node("GameManager"), "Falta autoload GameManager")
	assert_true(root.has_node("EconomyManager"), "Falta autoload EconomyManager")


func test_display_settings() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1080, "viewport_width")
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 1920, "viewport_height")
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 1, "orientación portrait")
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/Main.tscn", "main_scene")


func test_main_scene_structure() -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn") as PackedScene
	assert_true(packed != null, "Main.tscn no carga")
	if packed == null:
		return
	var state: SceneState = packed.get_state()
	var paths: PackedStringArray = PackedStringArray()
	for i: int in state.get_node_count():
		paths.append(str(state.get_node_path(i)))
	for required: String in [
		"./World/PlayerGrid", "./World/EnemyGrid", "./World/Lane",
		"./World/PlayerCastle", "./World/EnemyCastle",
		"./World/PlayerSpawn", "./World/EnemySpawn",
		"./Entities/PlayerUnits", "./Entities/EnemyUnits",
		"./Systems", "./Systems/CommandProcessor", "./Systems/DraftManager", "./World/LocalInput",
		"./Camera2D", "./UI/HUD", "./UI/HUD/DebugPanel",
	]:
		assert_true(paths.has(required), "Falta nodo %s en Main.tscn" % required)


func test_match_creates_two_players() -> void:
	var state: MatchState = GameManager.match_state
	assert_true(state != null, "MatchState nulo")
	assert_eq(state.players.size(), 2, "número de jugadores")
	assert_eq(state.get_player(0).player_id, 0, "player 0")
	assert_eq(state.get_player(1).player_id, 1, "player 1")
	assert_true(state.get_player(2) == null, "player 2 no debe existir")
	assert_eq(state.match_seed, TEST_SEED, "semilla")
	assert_true(GameManager.is_match_running(), "partida debe estar RUNNING")


func test_authority_in_vs_ai() -> void:
	assert_true(GameManager.is_authority(), "VS AI debe tener autoridad local")


func test_forward_directions() -> void:
	assert_eq(MatchTypes.forward_direction(MatchTypes.PLAYER_BOTTOM), Vector2(0, -1), "dirección player 0")
	assert_eq(MatchTypes.forward_direction(MatchTypes.PLAYER_TOP), Vector2(0, 1), "dirección player 1")
	assert_eq(MatchTypes.opponent_of(0), 1, "oponente de 0")
	assert_eq(MatchTypes.opponent_of(1), 0, "oponente de 1")


func test_spend_more_than_available_rejected() -> void:
	var start: int = EconomyManager.get_gold(0)
	assert_false(EconomyManager.spend_gold(0, start + 1), "gastar más de lo que hay debe fallar")
	assert_eq(EconomyManager.get_gold(0), start, "oro sin cambios")


func test_add_and_spend() -> void:
	var start: int = EconomyManager.get_gold(0)
	var opponent_start: int = EconomyManager.get_gold(1)
	assert_true(EconomyManager.add_gold(0, 30), "add_gold")
	assert_eq(EconomyManager.get_gold(0), start + 30, "oro tras añadir")
	assert_true(EconomyManager.has_gold(0, start + 30), "has_gold exacto")
	assert_true(EconomyManager.spend_gold(0, start + 20), "spend_gold válido")
	assert_eq(EconomyManager.get_gold(0), 10, "oro tras gastar")
	assert_false(EconomyManager.spend_gold(0, 11), "gastar más de lo que hay debe fallar")
	assert_eq(EconomyManager.get_gold(0), 10, "oro nunca negativo")
	assert_eq(EconomyManager.get_gold(1), opponent_start, "el oro del player 1 es independiente")


func test_negative_and_invalid_rejected() -> void:
	var start: int = EconomyManager.get_gold(0)
	assert_false(EconomyManager.add_gold(0, -5), "add negativo")
	assert_false(EconomyManager.spend_gold(0, -5), "spend negativo")
	assert_false(EconomyManager.add_gold(7, 5), "player inválido")
	assert_eq(EconomyManager.get_gold(0), start, "oro sin cambios")


func test_gold_signal_carries_player_id() -> void:
	var start: int = EconomyManager.get_gold(1)
	var received: Array[int] = []
	var listener: Callable = func(player_id: int, total: int) -> void:
		received.append(player_id)
		received.append(total)
	EventBus.oro_actualizado.connect(listener)
	EconomyManager.add_gold(1, 25)
	EventBus.oro_actualizado.disconnect(listener)
	assert_eq(received, [1, start + 25] as Array[int], "señal oro_actualizado(player_id, total)")


func test_no_gold_changes_after_match_end() -> void:
	EconomyManager.add_gold(0, 50)
	var frozen: int = EconomyManager.get_gold(0)
	GameManager.end_match(0)
	assert_false(GameManager.is_match_running(), "partida terminada")
	assert_false(EconomyManager.add_gold(0, 10), "add tras fin de partida")
	assert_false(EconomyManager.spend_gold(0, 10), "spend tras fin de partida")
	assert_eq(EconomyManager.get_gold(0), frozen, "oro congelado")
