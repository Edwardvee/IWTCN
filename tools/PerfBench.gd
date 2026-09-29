extends Node
## Banco de rendimiento: dos ejércitos grandes peleando sin gráficos y con
## el tiempo medido por fase. Sirve para comparar antes/después de optimizar.
##
## Uso:
##   godot --headless --path <proyecto> res://tools/PerfBench.tscn -- \
##       [--units=80] [--seconds=30] [--seed=7]
## --units = tropas por bando que se mantienen vivas (rellena cada segundo).
## Resultado por stdout; termina con código 0.

const STEP: float = 1.0 / 60.0
const MIX: Array[StringName] = [&"soldier", &"soldier", &"archer", &"archer", &"priest", &"tank"]

var _lane: LaneManager = null
var _grids: Array[GridManager] = []
var _processor: CommandProcessor = null
var _draft: DraftManager = null
var _replicator: StateReplicator = null


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: Dictionary = _parse_args()
	var units_per_team: int = int(args.get("units", "80"))
	var seconds: float = float(args.get("seconds", "30"))
	_build_fixture()
	GameManager.get_rules().max_units_per_team = maxi(units_per_team, 1)
	GameManager.start_match(MatchTypes.GameMode.SPECTATE, int(args.get("seed", "7")))
	GameManager.set_physics_process(false)
	_give_towers()
	_lane.profiling_enabled = true

	var ticks: int = roundi(seconds / STEP)
	var lane_us: PackedInt64Array = PackedInt64Array()
	var alive_total: int = 0
	var projectile_total: int = 0
	var peak_projectiles: int = 0
	var started: int = Time.get_ticks_usec()
	for tick: int in ticks:
		if not GameManager.is_match_running():
			break
		if tick % 60 == 0:
			_top_up(units_per_team)
		GameManager.match_state.match_time += STEP
		var before: int = Time.get_ticks_usec()
		_lane.simulate_step(STEP)
		lane_us.append(Time.get_ticks_usec() - before)
		alive_total += _lane.get_alive_units().size()
		var projectiles: int = _lane.get_projectile_count()
		projectile_total += projectiles
		peak_projectiles = maxi(peak_projectiles, projectiles)
		# Los castillos no deben caer durante el banco: se mantiene la carga.
		for player_id: int in MatchTypes.PLAYER_COUNT:
			GameManager.get_player_state(player_id).castle_hp = GameManager.get_player_state(player_id).castle_max_hp
	var total_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	var frames: int = lane_us.size()

	var sorted_us: PackedInt64Array = lane_us.duplicate()
	sorted_us.sort()
	var lane_sum: int = 0
	for value: int in lane_us:
		lane_sum += value
	print("")
	print("=== PerfBench: %d tropas/bando, %.0f s simulados (%d ticks) ===" % [units_per_team, seconds, frames])
	print("unidades vivas (media): %.0f · proyectiles (media/pico): %.1f / %d" % [alive_total / float(maxi(frames, 1)), projectile_total / float(maxi(frames, 1)), peak_projectiles])
	print("LaneManager.simulate_step: media %.3f ms · p50 %.3f · p99 %.3f · máx %.3f" % [
		lane_sum / 1000.0 / maxi(frames, 1), sorted_us[frames / 2] / 1000.0, sorted_us[int(frames * 0.99)] / 1000.0, sorted_us[frames - 1] / 1000.0])
	print("presupuesto por tick a 60 Hz: 16.667 ms → uso de la simulación: %.1f %%" % (lane_sum / 1000.0 / maxi(frames, 1) / 16.667 * 100.0))
	var phases: PackedStringArray = PackedStringArray()
	for phase: StringName in _lane.profile_us:
		phases.append("%s %.3f ms" % [phase, int(_lane.profile_us[phase]) / 1000.0 / maxi(frames, 1)])
	print("por fase (media por tick): %s" % " · ".join(phases))
	print("total (incluye relleno y medidas): %.0f ms" % total_ms)
	_measure_snapshots()
	_lane.clear_units()
	GameManager.register_command_processor(null)
	get_tree().quit(0)


func _parse_args() -> Dictionary:
	var parsed: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--"):
			var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
			parsed[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return parsed


func _build_fixture() -> void:
	_processor = CommandProcessor.new()
	_draft = DraftManager.new()
	_lane = LaneManager.new()
	var grid0: GridManager = GridManager.new()
	grid0.player_id = MatchTypes.PLAYER_BOTTOM
	grid0.position = Vector2(30.0, 2460.0)
	var grid1: GridManager = GridManager.new()
	grid1.player_id = MatchTypes.PLAYER_TOP
	grid1.position = Vector2(30.0, 40.0)
	_grids = [grid0, grid1]
	_replicator = StateReplicator.new()
	for node: Node in [_processor, _draft, _lane, grid0, grid1, _replicator]:
		add_child(node)
	for grid: GridManager in _grids:
		grid.lane = _lane
		_processor.register_grid(grid)
	_processor.register_lane(_lane)
	_processor.register_draft(_draft)
	_replicator.setup(_lane, _grids)
	GameManager.register_command_processor(_processor)
	for node: Node in [_draft, _lane, grid0, grid1]:
		node.set_physics_process(false)
	EconomyManager.set_physics_process(false)


## Torres construidas para que también disparen (carga de proyectiles).
func _give_towers() -> void:
	for player_id: int in MatchTypes.PLAYER_COUNT:
		for plot_index: int in [0, 1, 2]:
			GameManager.submit_command(UnlockPlotCommand.new(player_id, plot_index, GameCommand.Source.DEBUG))
		EconomyManager.add_gold(player_id, 5000)
		for slot_index: int in [0, 1, 4, 5]:
			GameManager.submit_command(BuildCommand.new(player_id, &"card_tower", slot_index, GameCommand.Source.DEBUG))


func _top_up(units_per_team: int) -> void:
	for team: int in MatchTypes.PLAYER_COUNT:
		var missing: int = units_per_team - _lane.get_alive_count(team)
		var mix_index: int = 0
		while missing > 0:
			var batch: int = mini(missing, 4)
			var unit_data: UnitData = GameManager.database.get_unit(MIX[(mix_index + team) % MIX.size()])
			# Ambos ejércitos aparecen en el centro del carril para forzar el choque.
			_lane.spawn_group_at(unit_data, team, batch, Vector2(540.0, 1600.0 + (20.0 if team == 0 else -20.0) * mix_index))
			missing -= batch
			mix_index += 1


## Coste de replicar/grabar el estado con muchas unidades.
func _measure_snapshots() -> void:
	var runs: int = 50
	var bytes: int = 0
	var started: int = Time.get_ticks_usec()
	for _run_index: int in runs:
		bytes += var_to_bytes(_replicator.build_snapshot()).size()
	var elapsed_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	print("snapshot: %.1f KB · construir+serializar %.3f ms" % [bytes / float(runs) / 1024.0, elapsed_ms / runs])
	var delta_cache: Dictionary = {}
	var delta_bytes: int = 0
	for _run_index: int in runs:
		delta_bytes += var_to_bytes(_replicator.build_delta_snapshot(delta_cache)).size()
	print("snapshot incremental (red y repeticiones): %.1f KB de media" % (delta_bytes / float(runs) / 1024.0))
	var memory_start: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var frames: Array[Dictionary] = []
	var recorder_cache: Dictionary = {}
	for _frame_index: int in 600:
		frames.append(_replicator.build_delta_snapshot(recorder_cache))
	var memory_mb: float = (Performance.get_monitor(Performance.MEMORY_STATIC) - memory_start) / 1048576.0
	print("600 snapshots (1 min de repetición) en memoria: %.1f MB" % memory_mb)
	print("nodos en el árbol: %d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
