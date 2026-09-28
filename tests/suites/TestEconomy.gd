extends TestSuite
## Fase 2: oro inicial e ingreso base (+5 cada 3 s) para ambos jugadores.

const PHYSICS_STEP: float = 1.0 / 60.0

var rules: GameRules


func before_each() -> void:
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 777)
	rules = GameManager.get_rules()


func test_starting_gold_for_both_players() -> void:
	assert_eq(rules.starting_gold, 20, "regla de oro inicial")
	assert_eq(EconomyManager.get_gold(0), 20, "player 0 empieza con 20")
	assert_eq(EconomyManager.get_gold(1), 20, "player 1 empieza con 20")


func test_restart_resets_gold() -> void:
	EconomyManager.add_gold(0, 500)
	EconomyManager.simulate_step(1.5)
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 778)
	assert_eq(EconomyManager.get_gold(0), 20, "nueva partida reinicia el oro")
	assert_eq(GameManager.get_player_state(0).base_income_timer, 0.0, "nueva partida reinicia el temporizador")


func test_no_income_before_interval() -> void:
	EconomyManager.simulate_step(2.5)
	assert_eq(EconomyManager.get_gold(0), 20, "sin ingreso a los 2.5 s")
	EconomyManager.simulate_step(0.5)
	assert_eq(EconomyManager.get_gold(0), 25, "+5 al llegar a 3 s")
	assert_eq(EconomyManager.get_gold(1), 25, "+5 también para el rival")


func test_ten_seconds_of_physics_frames() -> void:
	for _step: int in 600:
		EconomyManager.simulate_step(PHYSICS_STEP)
	# 10 s → ingresos en 3, 6 y 9 s.
	assert_eq(EconomyManager.get_gold(0), 35, "20 + 3 × 5 tras 10 s")
	assert_eq(EconomyManager.get_gold(1), 35, "rival igual")


func test_large_delta_pays_every_interval() -> void:
	EconomyManager.simulate_step(9.0)
	assert_eq(EconomyManager.get_gold(0), 35, "un salto de 9 s paga 3 veces")
	assert_true(GameManager.get_player_state(0).base_income_timer < rules.base_income_interval, "el resto queda acumulado")


func test_income_emits_signal_per_player() -> void:
	var received: Array[int] = []
	var listener: Callable = func(player_id: int, total: int) -> void:
		received.append(player_id)
		received.append(total)
	EventBus.oro_actualizado.connect(listener)
	EconomyManager.simulate_step(3.0)
	EventBus.oro_actualizado.disconnect(listener)
	assert_eq(received, [0, 25, 1, 25] as Array[int], "una señal por jugador, en orden de player_id")


func test_no_income_after_match_end() -> void:
	GameManager.end_match(MatchTypes.NO_PLAYER)
	EconomyManager.simulate_step(30.0)
	assert_eq(EconomyManager.get_gold(0), 20, "sin ingresos con la partida terminada")


func test_spending_never_goes_negative_with_income() -> void:
	assert_true(EconomyManager.spend_gold(0, 20), "gastar todo")
	assert_eq(EconomyManager.get_gold(0), 0, "0 de oro")
	assert_false(EconomyManager.spend_gold(0, 1), "no se puede gastar sin oro")
	EconomyManager.simulate_step(3.0)
	assert_eq(EconomyManager.get_gold(0), 5, "el ingreso sigue llegando")


func test_income_timer_is_serialized() -> void:
	EconomyManager.simulate_step(1.25)
	var snapshot: Dictionary = GameManager.match_state.to_dict()
	var players: Array = snapshot["players"]
	var player_zero: Dictionary = players[0]
	assert_eq(player_zero["gold"], 20, "oro en el snapshot")
	assert_true(is_equal_approx(player_zero["base_income_timer"], 1.25), "temporizador en el snapshot")
