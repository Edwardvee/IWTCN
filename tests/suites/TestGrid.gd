extends TestSuite
## Fase 3: grid de 24 slots, plots desbloqueables, construir, ocupar, vender
## y nivel = nº de estructuras del mismo tipo. Todo a través de comandos.

const LOCAL: GameCommand.Source = GameCommand.Source.LOCAL_PLAYER
const DEBUG: GameCommand.Source = GameCommand.Source.DEBUG
## Plot inicial (gratis) = 4 → slots 16..19.
const START_SLOT: int = 16

var processor: CommandProcessor = null
var grid0: GridManager = null
var grid1: GridManager = null
var input: LocalInputController = null
var rejections: PackedStringArray = PackedStringArray()


func before_each() -> void:
	if processor == null:
		_build_fixture()
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 4242)
	rejections.clear()


func after_all() -> void:
	GameManager.register_command_processor(null)
	EventBus.comando_rechazado.disconnect(_on_rejected)
	for node: Node in [processor, grid0, grid1, input]:
		node.queue_free()


func _build_fixture() -> void:
	processor = CommandProcessor.new()
	grid0 = GridManager.new()
	grid0.player_id = 0
	grid0.position = Vector2(30.0, 2460.0)
	grid1 = GridManager.new()
	grid1.player_id = 1
	grid1.position = Vector2(30.0, 40.0)
	input = LocalInputController.new()
	for node: Node in [processor, grid0, grid1, input]:
		get_root().add_child(node)
	for grid: GridManager in [grid0, grid1]:
		processor.register_grid(grid)
		input.register_grid(grid)
	GameManager.register_command_processor(processor)
	EventBus.comando_rechazado.connect(_on_rejected)


func _on_rejected(_player_id: int, _command_type: StringName, reason: String) -> void:
	rejections.append(reason)


## BuildCommand es solo de debug desde la Fase 9 (el jugador compra en la tienda).
func _build(player_id: int, card_id: StringName, slot_index: int, source: GameCommand.Source = DEBUG) -> bool:
	return GameManager.submit_command(BuildCommand.new(player_id, card_id, slot_index, source))


func _gold(player_id: int) -> int:
	return EconomyManager.get_gold(player_id)


func test_24_slots_per_grid() -> void:
	assert_eq(grid0.get_slot_count(), 24, "24 slots player 0")
	assert_eq(grid1.get_slot_count(), 24, "24 slots player 1")
	assert_eq(GridState.plot_of_slot(0), 0, "slot 0 → plot 0")
	assert_eq(GridState.plot_of_slot(23), 5, "slot 23 → plot 5")
	assert_eq(GridState.plot_of_slot(24), -1, "slot 24 inválido")


func test_initial_plots() -> void:
	for grid: GridManager in [grid0, grid1]:
		for plot_index: int in GridState.PLOT_COUNT:
			assert_eq(grid.get_state().is_plot_unlocked(plot_index), plot_index == 4, "P%d plot %d" % [grid.player_id, plot_index])


func test_build_farm() -> void:
	EconomyManager.add_gold(0, 100)
	assert_true(_build(0, &"card_farm", START_SLOT), "construir farm")
	assert_eq(_gold(0), 70, "120 - 50")
	var structure: StructureBase = grid0.get_structure_at(START_SLOT)
	assert_true(structure != null, "nodo StructureBase creado")
	assert_eq(structure.data.id, &"farm", "es una farm")
	assert_eq(structure.level, 1, "Lv1")
	assert_eq(structure.owner_id, 0, "dueño player 0")
	assert_true(structure.building_id > 0, "building_id lógico asignado")
	assert_false(grid0.get_state().is_slot_free(START_SLOT), "slot ocupado en el estado")


func test_build_on_occupied_slot_rejected() -> void:
	EconomyManager.add_gold(0, 200)
	_build(0, &"card_farm", START_SLOT)
	var gold_before: int = _gold(0)
	assert_false(_build(0, &"card_tower", START_SLOT), "slot ocupado")
	assert_eq(_gold(0), gold_before, "no se cobra")
	assert_eq(rejections, PackedStringArray(["Slot ocupado"]), "motivo del rechazo")


func test_build_on_locked_plot_rejected() -> void:
	EconomyManager.add_gold(0, 100)
	assert_false(_build(0, &"card_farm", 0), "plot 0 bloqueado")
	assert_eq(_gold(0), 120, "no se cobra")
	assert_true(grid0.get_structure_at(0) == null, "sin estructura")


func test_build_without_gold_rejected() -> void:
	assert_false(_build(0, &"card_farm", START_SLOT), "20 < 50")
	assert_eq(_gold(0), 20, "oro intacto")
	assert_true(grid0.get_state().is_slot_free(START_SLOT), "slot sigue libre")


func test_build_with_non_structure_card_rejected() -> void:
	EconomyManager.add_gold(0, 100)
	assert_false(_build(0, &"card_soldiers", START_SLOT), "carta de unidad no construye")
	assert_false(_build(0, &"card_inexistente", START_SLOT), "carta desconocida")


func test_unlock_plot() -> void:
	assert_true(GameManager.submit_command(UnlockPlotCommand.new(0, 5)), "desbloquear plot 5 (10)")
	assert_eq(_gold(0), 10, "20 - 10")
	assert_true(grid0.get_state().is_plot_unlocked(5), "plot 5 desbloqueado")
	assert_false(GameManager.submit_command(UnlockPlotCommand.new(0, 5)), "ya desbloqueado")
	assert_false(GameManager.submit_command(UnlockPlotCommand.new(0, 3)), "plot 3 cuesta 50")
	assert_false(grid0.get_state().is_plot_unlocked(3), "plot 3 sigue bloqueado")
	assert_eq(_gold(0), 10, "oro nunca negativo")
	assert_false(GameManager.submit_command(UnlockPlotCommand.new(0, 9)), "plot inválido")


func test_build_in_unlocked_plot() -> void:
	EconomyManager.add_gold(0, 100)
	GameManager.submit_command(UnlockPlotCommand.new(0, 5))
	assert_true(_build(0, &"card_farm", 20), "slot 20 del plot 5")


func test_sell_refunds_half() -> void:
	EconomyManager.add_gold(0, 100)
	_build(0, &"card_farm", START_SLOT)
	assert_eq(_gold(0), 70, "tras construir")
	assert_true(GameManager.submit_command(SellCommand.new(0, START_SLOT)), "vender")
	assert_eq(_gold(0), 95, "70 + 25 (la mitad de 50)")
	assert_true(grid0.get_state().is_slot_free(START_SLOT), "slot liberado")
	assert_true(grid0.get_structure_at(START_SLOT) == null, "nodo retirado")
	assert_true(_build(0, &"card_tower", START_SLOT), "el slot liberado se puede reutilizar")


func test_sell_empty_slot_rejected() -> void:
	assert_false(GameManager.submit_command(SellCommand.new(0, START_SLOT)), "vender vacío")
	assert_eq(_gold(0), 20, "sin reembolso")


func test_level_equals_structure_count() -> void:
	EconomyManager.add_gold(0, 1000)
	var levels: Array[int] = []
	var listener: Callable = func(_pid: int, _slot: int, _data: StructureData, nivel: int) -> void:
		levels.append(nivel)
	EventBus.estructura_construida.connect(listener)
	_build(0, &"card_farm", 16)
	_build(0, &"card_farm", 17)
	_build(0, &"card_tower", 18)
	EventBus.estructura_construida.disconnect(listener)
	assert_eq(levels, [1, 2, 1] as Array[int], "nivel emitido = nº de ese tipo")
	assert_eq(grid0.get_structure_at(16).level, 2, "primera farm sube a Lv2")
	assert_eq(grid0.get_structure_at(17).level, 2, "segunda farm Lv2")
	assert_eq(grid0.get_structure_at(18).level, 1, "tower Lv1")
	GameManager.submit_command(SellCommand.new(0, 16))
	assert_eq(grid0.get_structure_at(17).level, 1, "al vender una farm, la otra baja a Lv1")


func test_max_five_per_type() -> void:
	EconomyManager.add_gold(0, 1000)
	GameManager.submit_command(UnlockPlotCommand.new(0, 5))
	for slot_index: int in [16, 17, 18, 19, 20]:
		assert_true(_build(0, &"card_farm", slot_index), "farm %d" % slot_index)
	assert_false(_build(0, &"card_farm", 21), "sexta farm rechazada")
	assert_eq(grid0.get_structure_at(16).level, 5, "Lv5")
	assert_true(_build(0, &"card_tower", 21), "otro tipo sí se puede")


func test_count_barracks_tag() -> void:
	EconomyManager.add_gold(0, 1000)
	_build(0, &"card_soldier_barracks", 16)
	_build(0, &"card_soldier_barracks", 17)
	_build(0, &"card_archer_barracks", 18)
	_build(0, &"card_church", 19)
	assert_eq(grid0.count_structures_with_tag(&"barracks"), 3, "2 soldier + 1 archer = 3 cuarteles")


func test_local_player_cannot_command_enemy() -> void:
	EconomyManager.add_gold(1, 100)
	assert_false(_build(1, &"card_farm", START_SLOT, LOCAL), "LOCAL_PLAYER no controla al player 1")
	assert_true(_build(1, &"card_farm", START_SLOT, DEBUG), "DEBUG sí (build de depuración)")


func test_players_are_independent() -> void:
	EconomyManager.add_gold(1, 100)
	_build(1, &"card_farm", START_SLOT, DEBUG)
	assert_true(grid0.get_state().is_slot_free(START_SLOT), "grid del player 0 intacto")
	assert_eq(_gold(0), 20, "oro del player 0 intacto")
	assert_eq(grid1.get_structure_at(START_SLOT).owner_id, 1, "estructura del player 1")


func test_building_ids_unique() -> void:
	EconomyManager.add_gold(0, 1000)
	_build(0, &"card_farm", 16)
	_build(0, &"card_farm", 17)
	assert_true(grid0.get_structure_at(16).building_id != grid0.get_structure_at(17).building_id, "ids distintos")


func test_geometry_hit_testing() -> void:
	for grid: GridManager in [grid0, grid1]:
		for slot_index: int in GridState.SLOT_COUNT:
			var point: Vector2 = grid.get_slot_world_position(slot_index)
			assert_eq(grid.get_slot_index_at(point), slot_index, "P%d hit slot %d" % [grid.player_id, slot_index])


func test_front_row_faces_the_lane() -> void:
	# Player 0: la fila delantera (plots 0-2) queda arriba, hacia el carril.
	assert_true(grid0.get_slot_world_position(0).y < grid0.get_slot_world_position(START_SLOT).y, "P0 delante = arriba")
	# Player 1 espejado: su fila delantera queda abajo, hacia el carril.
	assert_true(grid1.get_slot_world_position(0).y > grid1.get_slot_world_position(START_SLOT).y, "P1 delante = abajo")


func test_resolve_drop_slot_on_plot() -> void:
	var plot_center: Vector2 = grid0.to_global(grid0.get_plot_rect(4).get_center())
	assert_eq(grid0.resolve_drop_slot(plot_center), 16, "soltar en el plot → primer slot libre")
	EconomyManager.add_gold(0, 100)
	_build(0, &"card_farm", 16)
	assert_eq(grid0.resolve_drop_slot(plot_center), 17, "siguiente slot libre")
	assert_eq(grid0.resolve_drop_slot(grid0.get_slot_world_position(19)), 19, "soltar sobre un slot libre → ese slot")
	assert_eq(grid0.resolve_drop_slot(grid0.get_slot_world_position(0)), -1, "plot bloqueado → -1")


func test_tap_selects_slot_and_unlocks_plot() -> void:
	input.handle_tap(grid0.get_slot_world_position(17))
	assert_eq(input.selected_player_id, 0, "selección player 0")
	assert_eq(input.selected_slot, 17, "slot 17 seleccionado")
	input.handle_tap(grid0.get_slot_world_position(20))
	assert_true(grid0.get_state().is_plot_unlocked(5), "tocar plot bloqueado lo compra")
	assert_eq(_gold(0), 10, "cobra el coste del plot")
	input.handle_tap(Vector2(540.0, 1500.0))
	assert_eq(input.selected_slot, -1, "tocar fuera deselecciona")


func test_snapshot_contains_grid() -> void:
	EconomyManager.add_gold(0, 100)
	_build(0, &"card_farm", START_SLOT)
	var snapshot: Dictionary = GameManager.match_state.to_dict()
	var player_zero: Dictionary = (snapshot["players"] as Array)[0]
	var grid_dict: Dictionary = player_zero["grid"]
	var slot_dict: Dictionary = (grid_dict["slots"] as Array)[START_SLOT]
	assert_eq(slot_dict["structure_id"], &"farm", "estructura en el snapshot")
	assert_eq(slot_dict["invested_gold"], 50, "oro invertido en el snapshot")


func test_restart_clears_grid() -> void:
	EconomyManager.add_gold(0, 100)
	_build(0, &"card_farm", START_SLOT)
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 5)
	assert_true(grid0.get_state().is_slot_free(START_SLOT), "estado limpio")
	assert_true(grid0.get_structure_at(START_SLOT) == null, "nodos limpios")
