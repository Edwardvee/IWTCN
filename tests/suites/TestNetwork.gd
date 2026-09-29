extends TestSuite
## Fase 14: serialización de comandos y aplicación de snapshots (sin red real;
## la prueba con dos procesos está en tests/network/).

var server_lane: LaneManager = null
var client_lane: LaneManager = null


func before_each() -> void:
	if server_lane == null:
		server_lane = LaneManager.new()
		client_lane = LaneManager.new()
		get_root().add_child(server_lane)
		get_root().add_child(client_lane)
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 1414)


func after_all() -> void:
	server_lane.clear_units()
	client_lane.clear_units()
	server_lane.queue_free()
	client_lane.queue_free()


func test_play_card_round_trip() -> void:
	var original: PlayCardCommand = PlayCardCommand.new(0, 2, &"card_soldiers", 7, Vector2(540.0, 1900.0))
	var decoded: PlayCardCommand = CommandCodec.decode(CommandCodec.encode(original)) as PlayCardCommand
	assert_true(decoded != null, "decodifica play_card")
	assert_eq(decoded.offer_index, 2, "offer_index")
	assert_eq(decoded.card_id, &"card_soldiers", "card_id")
	assert_eq(decoded.slot_index, 7, "slot_index")
	assert_eq(decoded.deploy_position, Vector2(540.0, 1900.0), "deploy_position")
	assert_eq(decoded.source, GameCommand.Source.NETWORK, "source NETWORK")
	assert_eq(decoded.player_id, MatchTypes.NO_PLAYER, "el player_id no viaja: lo fija el servidor")


func test_other_player_commands_round_trip() -> void:
	var sell: SellCommand = CommandCodec.decode(CommandCodec.encode(SellCommand.new(0, 5))) as SellCommand
	assert_eq(sell.slot_index, 5, "sell")
	var unlock: UnlockPlotCommand = CommandCodec.decode(CommandCodec.encode(UnlockPlotCommand.new(0, 3))) as UnlockPlotCommand
	assert_eq(unlock.plot_index, 3, "unlock_plot")
	assert_true(CommandCodec.decode(CommandCodec.encode(RerollShopCommand.new(0))) is RerollShopCommand, "reroll_shop")


func test_debug_commands_never_decode() -> void:
	for command: GameCommand in [DebugAddGoldCommand.new(0, 999), DebugSpawnUnitCommand.new(0, &"tank", 5),
			BuildCommand.new(0, &"card_farm", 16, GameCommand.Source.DEBUG), DebugDamageCastleCommand.new(1, 3000.0)]:
		assert_true(CommandCodec.decode(CommandCodec.encode(command)) == null, "%s no se acepta desde la red" % command.get_type())


func test_malformed_data_rejected() -> void:
	assert_true(CommandCodec.decode({"type": "play_card", "offer_index": "0"}) == null, "tipos incorrectos")
	assert_true(CommandCodec.decode({"type": "sell"}) == null, "campo ausente")
	assert_true(CommandCodec.decode({}) == null, "vacío")


func test_grid_state_apply_dict() -> void:
	var source: GridState = GridState.new(PackedInt32Array([4]))
	source.unlock_plot(1)
	source.place_structure(17, &"farm", 42, 50)
	var target: GridState = GridState.new(PackedInt32Array([4]))
	target.apply_dict(source.to_dict())
	assert_true(target.is_plot_unlocked(1), "plot desbloqueado replicado")
	assert_eq(target.get_slot(17).structure_id, &"farm", "estructura replicada")
	assert_eq(target.get_slot(17).building_id, 42, "id lógico replicado")
	assert_eq(str(target.to_dict()), str(source.to_dict()), "estado idéntico")


func test_lane_snapshot_creates_updates_and_removes_units() -> void:
	var soldier: UnitData = GameManager.database.get_unit(&"soldier")
	var ally: UnitBase = server_lane.spawn_unit(soldier, 0, Vector2(540.0, 2000.0))
	var enemy: UnitBase = server_lane.spawn_unit(soldier, 1, Vector2(540.0, 1200.0))
	enemy.receive_damage(100.0, 0)
	client_lane.apply_snapshot(server_lane.to_snapshot())
	var mirrored: UnitBase = client_lane.get_unit(enemy.unit_id)
	assert_eq(client_lane.get_alive_units().size(), 2, "crea las unidades replicadas")
	assert_true(mirrored != null and mirrored.team == 1, "mismo id lógico y equipo")
	assert_eq(mirrored.current_hp, 150.0, "vida replicada")
	server_lane.convert_unit(enemy, 0)
	ally.receive_damage(9999.0, 0)
	server_lane.simulate_step(1.0 / 60.0)
	client_lane.apply_snapshot(server_lane.to_snapshot())
	assert_eq(mirrored.team, 0, "la conversión se replica sobre la misma instancia")
	assert_true(client_lane.get_unit(ally.unit_id) == null, "las unidades muertas se retiran")
