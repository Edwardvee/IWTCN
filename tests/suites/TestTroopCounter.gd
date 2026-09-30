extends TestSuite
## Contador de tropas de la esquina: vivas/límite del jugador local.


func test_shows_alive_over_cap() -> void:
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 5555)
	var lane: LaneManager = LaneManager.new()
	get_root().add_child(lane)
	var counter: TroopCounter = TroopCounter.new()
	counter.lane = lane
	get_root().add_child(counter)
	assert_eq(counter.get_text(), "0/%d" % lane.get_unit_cap(0), "empieza en 0")
	lane.spawn_unit(GameManager.database.get_unit(&"soldier"), 0, Vector2(540.0, 2200.0))
	lane.spawn_unit(GameManager.database.get_unit(&"archer"), 0, Vector2(500.0, 2200.0))
	lane.spawn_unit(GameManager.database.get_unit(&"soldier"), 1, Vector2(540.0, 1000.0))
	counter._refresh()
	assert_eq(counter.get_text(), "2/%d" % lane.get_unit_cap(0), "solo cuenta las tropas propias")
	lane.clear_units()
	counter.queue_free()
	lane.queue_free()
