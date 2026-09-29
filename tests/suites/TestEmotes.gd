extends TestSuite
## Emotes: comando validado por la autoridad, tiempo de espera de 3 s, viaje por red.

var processor: CommandProcessor = null
var _received: Array[Array] = []


func before_each() -> void:
	if processor == null:
		processor = CommandProcessor.new()
		get_root().add_child(processor)
		EventBus.emote_mostrado.connect(func(player_id: int, emote_id: StringName) -> void: _received.append([player_id, emote_id]))
	GameManager.register_command_processor(processor)
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 4242)
	_received.clear()


func after_all() -> void:
	GameManager.register_command_processor(null)
	processor.queue_free()


func test_there_are_four_emotes_with_art() -> void:
	assert_eq(Emotes.IDS.size(), 4, "cuatro emotes")
	assert_true(Emotes.IDS.has(&"goblin_laugh"), "hay un goblin riéndose")
	for emote_id: StringName in Emotes.IDS:
		assert_true(Emotes.get_texture(emote_id) != null, "arte de '%s'" % emote_id)
	assert_eq(Emotes.COOLDOWN, 3.0, "espera de 3 segundos")


func test_emote_is_applied_and_announced() -> void:
	assert_true(GameManager.submit_command(EmoteCommand.new(0, &"goblin_laugh")), "emote aceptado")
	assert_eq(_received.size(), 1, "un evento emote_mostrado")
	assert_eq(_received[0], [0, &"goblin_laugh"], "jugador y emote del evento")
	var state: PlayerState = GameManager.get_player_state(0)
	assert_eq(state.emote_id, &"goblin_laugh", "estado: último emote")
	assert_eq(state.emote_seq, 1, "estado: contador")


func test_unknown_emote_rejected() -> void:
	assert_false(GameManager.submit_command(EmoteCommand.new(0, &"no_existe")), "emote inexistente")
	assert_true(_received.is_empty(), "sin evento")


func test_cannot_spam_emotes() -> void:
	assert_true(GameManager.submit_command(EmoteCommand.new(0, &"cry")), "primer emote")
	assert_false(GameManager.submit_command(EmoteCommand.new(0, &"angry")), "segundo inmediato rechazado")
	GameManager.match_state.match_time += 1.5
	assert_false(GameManager.submit_command(EmoteCommand.new(0, &"angry")), "a mitad de la espera sigue rechazado")
	GameManager.match_state.match_time += 1.6
	assert_true(GameManager.submit_command(EmoteCommand.new(0, &"gg")), "pasados los 3 s se puede")
	assert_eq(_received.size(), 2, "solo llegaron los dos aceptados")
	assert_eq(GameManager.get_player_state(0).emote_seq, 2, "contador = 2")


func test_cooldown_is_per_player() -> void:
	assert_true(GameManager.submit_command(EmoteCommand.new(0, &"cry")), "jugador 0")
	var rival: EmoteCommand = EmoteCommand.new(1, &"angry", GameCommand.Source.AI)
	assert_true(GameManager.submit_command(rival), "el rival tiene su propia espera")


func test_codec_round_trip_and_validation() -> void:
	var decoded: EmoteCommand = CommandCodec.decode(CommandCodec.encode(EmoteCommand.new(0, &"gg"))) as EmoteCommand
	assert_true(decoded != null, "decodifica emote")
	assert_eq(decoded.emote_id, &"gg", "emote_id")
	assert_eq(decoded.source, GameCommand.Source.NETWORK, "source NETWORK")
	assert_eq(decoded.player_id, MatchTypes.NO_PLAYER, "el player_id no viaja")
	assert_true(CommandCodec.decode({"type": "emote", "emote_id": "inventado"}) == null, "emote desconocido no se decodifica")
	assert_true(CommandCodec.decode({"type": "emote"}) == null, "sin emote_id")


func test_snapshot_carries_last_emote() -> void:
	GameManager.submit_command(EmoteCommand.new(0, &"angry"))
	var player_dict: Dictionary = GameManager.get_player_state(0).to_dict()
	assert_eq(player_dict["emote"], &"angry", "snapshot: emote")
	assert_eq(player_dict["emote_seq"], 1, "snapshot: contador")
