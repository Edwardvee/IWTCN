extends TestSuite
## Menú de partida: rendirse termina la partida con derrota, se envía por red y el
## menú solo pausa el juego contra la IA.

var processor: CommandProcessor = null


func before_each() -> void:
	if processor == null:
		processor = CommandProcessor.new()
		get_root().add_child(processor)
	GameManager.register_command_processor(processor)
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 2222)


func after_all() -> void:
	GameManager.register_command_processor(null)
	get_root().get_tree().paused = false
	processor.queue_free()


func test_surrender_ends_the_match_with_the_rival_winning() -> void:
	assert_true(GameManager.is_match_running(), "partida en curso")
	assert_true(GameManager.submit_command(SurrenderCommand.new(0)), "rendirse aceptado")
	assert_false(GameManager.is_match_running(), "la partida terminó")
	assert_eq(GameManager.match_state.winner_player_id, 1, "gana el rival")


func test_the_rival_cannot_surrender_for_you() -> void:
	assert_false(GameManager.submit_command(SurrenderCommand.new(1)), "no puedes rendirte por otro jugador")
	assert_true(GameManager.is_match_running(), "la partida sigue")


func test_surrender_travels_over_the_network() -> void:
	var decoded: SurrenderCommand = CommandCodec.decode(CommandCodec.encode(SurrenderCommand.new(0))) as SurrenderCommand
	assert_true(decoded != null, "decodifica surrender")
	assert_eq(decoded.source, GameCommand.Source.NETWORK, "source NETWORK")
	assert_eq(decoded.player_id, MatchTypes.NO_PLAYER, "el player_id lo fija el servidor")


func test_menu_pauses_only_against_the_ai() -> void:
	var menu: PauseMenu = PauseMenu.new()
	get_root().add_child(menu)
	GameManager.game_mode = MatchTypes.GameMode.VS_AI
	assert_true(menu.pauses_game(), "VS IA: pausa")
	GameManager.game_mode = MatchTypes.GameMode.ONLINE
	assert_false(menu.pauses_game(), "online: no pausa")
	GameManager.game_mode = MatchTypes.GameMode.VS_AI
	menu.queue_free()
