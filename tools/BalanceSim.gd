extends Node
## Simulador de equilibrio y ritmo: IA contra IA sin gráficos, a máxima
## velocidad, con las reglas reales de data/. Enfrenta perfiles de IA
## (RuleBasedStrategy.PROFILES) en ambos lados del mapa con varias semillas y
## resume quién gana, cuánto duran las partidas y cómo transcurren.
##
## Uso:
##   godot --headless --path <proyecto> res://tools/BalanceSim.tscn -- \
##       [--matches=4] [--profiles=balanced,rush,...] [--max-time=900] \
##       [--seed=1000] [--csv=ruta.csv] [--quiet] [--verbose] ##       [--set=rules.castle_max_hp=10000] [--set=unit.soldier.damage=30] ...
## Los perfiles admiten "@raza" (balanced@goblin, rush@elf): así se enfrentan razas.
## --set sustituye un valor de los datos solo en esta ejecución (no toca los
## .tres), para probar cambios de equilibrio sin editar archivos. Rutas:
## rules.<campo> · unit.<id>.<campo> · structure.<id>.<campo> · card.<id>.<campo> · race.<id>.<campo>.
## Las listas se escriben con "/" (structure.farm.income_per_level=25/40/60/80/100).
## Termina con código 0. El informe sale por stdout.

const STEP: float = 1.0 / 60.0
const SAMPLE_INTERVAL: float = 1.0

class MatchResult:
	var seed_value: int = 0
	var profiles: Array[StringName] = [&"", &""]
	var winner: int = MatchTypes.NO_PLAYER
	var timed_out: bool = false
	var duration: float = 0.0
	var first_combat: float = -1.0
	var first_castle_hit: float = -1.0
	var castle_hp_ratio: Array[float] = [1.0, 1.0]
	var earned: Array[int] = [0, 0]
	var peak_gold: Array[int] = [0, 0]
	var units_spawned: Array[int] = [0, 0]
	var army_seconds: Array[float] = [0.0, 0.0]
	var structures: Array[Dictionary] = [{}, {}]
	var plots_unlocked: Array[int] = [0, 0]

var _processor: CommandProcessor = null
var _draft: DraftManager = null
var _lane: LaneManager = null
var _grids: Array[GridManager] = []
var _ais: Array[AIController] = []

var _overrides: Array[String] = []
var _current: MatchResult = null
var _last_gold: Array[int] = [0, 0]
var _max_time: float = 900.0
var _verbose: bool = false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: Dictionary = _parse_args()
	var per_pair: int = int(args.get("matches", "3"))
	var base_seed: int = int(args.get("seed", "1000"))
	_max_time = float(args.get("max-time", "900"))
	var quiet: bool = args.has("quiet")
	_verbose = args.has("verbose")
	var profiles: Array[StringName] = []
	for profile_name: String in str(args.get("profiles", ",".join(RuleBasedStrategy.PROFILES))).split(","):
		profiles.append(StringName(profile_name))
	_build_fixture()
	for override: String in _overrides:
		if not _apply_override(override):
			push_error("Override inválido: %s" % override)
			get_tree().quit(2)
			return
	var results: Array[MatchResult] = []
	var started_at: int = Time.get_ticks_msec()
	for bottom: StringName in profiles:
		for top: StringName in profiles:
			for index: int in per_pair:
				var result: MatchResult = _play_match(bottom, top, base_seed + index * 7919 + results.size())
				results.append(result)
				if quiet:
					continue
				print("[%d] %s (abajo) vs %s (arriba): %s en %s" % [results.size(), bottom, top, _describe_winner(result), BalanceReport.format_time(result.duration)])
	print("Simuladas %d partidas en %.1f s reales" % [results.size(), (Time.get_ticks_msec() - started_at) / 1000.0])
	if not _overrides.is_empty():
		print("Overrides: %s" % ", ".join(_overrides))
	print(BalanceReport.summarize(results_to_rows(results), profiles))
	if args.has("csv"):
		_write_csv(str(args["csv"]), results)
	_cleanup()
	get_tree().quit(0)


func _describe_winner(result: MatchResult) -> String:
	if result.timed_out:
		return "TIEMPO AGOTADO"
	match result.winner:
		MatchTypes.PLAYER_BOTTOM:
			return "gana abajo"
		MatchTypes.PLAYER_TOP:
			return "gana arriba"
	return "empate"


func _parse_args() -> Dictionary:
	var parsed: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--"):
			continue
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if parts[0] == "set" and parts.size() > 1:
			_overrides.append(parts[1])
		else:
			parsed[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return parsed


## "unit.soldier.damage=30" → cambia el valor en memoria. Devuelve false si la
## ruta o el valor no son válidos.
func _apply_override(override: String) -> bool:
	var assignment: PackedStringArray = override.split("=", true, 1)
	if assignment.size() != 2:
		return false
	var path: PackedStringArray = assignment[0].split(".")
	var resource: Resource = null
	var field: String = ""
	match path[0]:
		"rules":
			if path.size() != 2:
				return false
			resource = GameManager.get_rules()
			field = path[1]
		"unit", "structure", "card", "race":
			if path.size() != 3:
				return false
			var database: GameDatabase = GameManager.database
			var entity_id: StringName = StringName(path[1])
			match path[0]:
				"unit":
					resource = database.get_unit(entity_id)
				"structure":
					resource = database.get_structure(entity_id)
				"card":
					resource = database.get_card(entity_id)
				"race":
					resource = database.get_race(entity_id)
			field = path[2]
		_:
			return false
	if resource == null or not field in resource:
		return false
	var current: Variant = resource.get(field)
	var raw: String = assignment[1]
	var converted: Variant = null
	match typeof(current):
		TYPE_INT:
			converted = int(raw)
		TYPE_FLOAT:
			converted = float(raw)
		TYPE_BOOL:
			converted = raw == "true"
		TYPE_PACKED_INT32_ARRAY:
			var ints: PackedInt32Array = PackedInt32Array()
			for item: String in raw.split("/"):
				ints.append(int(item))
			converted = ints
		TYPE_PACKED_FLOAT32_ARRAY:
			var floats: PackedFloat32Array = PackedFloat32Array()
			for item: String in raw.split("/"):
				floats.append(float(item))
			converted = floats
		_:
			return false
	resource.set(field, converted)
	return true


# --- Fixture -----------------------------------------------------------------------

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
	for player_id: int in MatchTypes.PLAYER_COUNT:
		var ai: AIController = AIController.new()
		_ais.append(ai)
	for node: Node in [_processor, _draft, _lane, grid0, grid1, _ais[0], _ais[1]]:
		add_child(node)
	for grid: GridManager in _grids:
		grid.lane = _lane
		_processor.register_grid(grid)
	_processor.register_lane(_lane)
	_processor.register_draft(_draft)
	_ais[0].setup(MatchTypes.PLAYER_BOTTOM, _draft, grid0, _lane)
	_ais[1].setup(MatchTypes.PLAYER_TOP, _draft, grid1, _lane)
	GameManager.register_command_processor(_processor)
	# Los nodos se simulan a mano: se desactiva su _physics_process.
	for node: Node in [_draft, _lane, grid0, grid1, _ais[0], _ais[1]]:
		node.set_physics_process(false)
	EconomyManager.set_physics_process(false)
	GameManager.set_physics_process(false)
	EventBus.unidad_vida_cambiada.connect(_on_unit_hp_changed)
	EventBus.castillo_danado.connect(_on_castle_damaged)
	EventBus.unidad_desplegada.connect(_on_unit_spawned)
	EventBus.oro_actualizado.connect(_on_gold_changed)


func _cleanup() -> void:
	GameManager.register_command_processor(null)
	_lane.clear_units()


# --- Una partida ---------------------------------------------------------------------

func _play_match(bottom: StringName, top: StringName, seed_value: int) -> MatchResult:
	_current = MatchResult.new()
	_current.seed_value = seed_value
	_current.profiles = [bottom, top]
	_last_gold = [0, 0]
	# "estilo@raza" (p. ej. rush@goblin) fija la raza de ese lado; sin raza, humanos.
	var bottom_parts: PackedStringArray = str(bottom).split("@")
	var top_parts: PackedStringArray = str(top).split("@")
	AIDifficulty.apply_by_name(_ais[0], StringName(bottom_parts[0]))
	AIDifficulty.apply_by_name(_ais[1], StringName(top_parts[0]))
	GameManager.match_races = [StringName(bottom_parts[1]) if bottom_parts.size() > 1 else &"human", StringName(top_parts[1]) if top_parts.size() > 1 else &"human"]
	GameManager.start_match(MatchTypes.GameMode.SPECTATE, seed_value)
	GameManager.set_physics_process(false)
	var sample_timer: float = 0.0
	while GameManager.is_match_running():
		var match_state: MatchState = GameManager.match_state
		if match_state.match_time >= _max_time:
			_current.timed_out = true
			break
		match_state.match_time += STEP
		EconomyManager.simulate_step(STEP)
		_draft.simulate_step(STEP)
		for grid: GridManager in _grids:
			grid.simulate_step(STEP)
		_lane.simulate_step(STEP)
		for ai: AIController in _ais:
			ai.simulate_step(STEP)
		sample_timer += STEP
		if sample_timer >= SAMPLE_INTERVAL:
			sample_timer -= SAMPLE_INTERVAL
			if _verbose and int(match_state.match_time) % 90 == 0:
				_dump_units()
			if _verbose and int(match_state.match_time) % 30 == 0:
				print("   t=%ds unidades %d/%d castillos %.0f/%.0f oro %d/%d" % [int(match_state.match_time), _lane.get_alive_count(0), _lane.get_alive_count(1), match_state.get_player(0).castle_hp, match_state.get_player(1).castle_hp, match_state.get_player(0).gold, match_state.get_player(1).gold])
			for player_id: int in MatchTypes.PLAYER_COUNT:
				_current.army_seconds[player_id] += _lane.get_alive_count(player_id)
	_finish_result()
	return _current


## Depuración de atascos: resumen de las unidades vivas por bando, tipo y estado.
func _dump_units() -> void:
	var summary: Dictionary = {}
	var min_y: float = INF
	var max_y: float = -INF
	for unit: UnitBase in _lane.get_alive_units():
		var key: String = "%d/%s/%s" % [unit.team, unit.data.id, unit.get_state_name()]
		summary[key] = int(summary.get(key, 0)) + 1
		min_y = minf(min_y, unit.global_position.y)
		max_y = maxf(max_y, unit.global_position.y)
	print("   unidades: %s · y %.0f..%.0f" % [str(summary), min_y, max_y])


func _finish_result() -> void:
	var match_state: MatchState = GameManager.match_state
	_current.duration = match_state.match_time
	_current.winner = match_state.winner_player_id
	for player_id: int in MatchTypes.PLAYER_COUNT:
		var player_state: PlayerState = match_state.get_player(player_id)
		_current.castle_hp_ratio[player_id] = player_state.castle_hp / player_state.castle_max_hp
		var counts: Dictionary = {}
		for slot_index: int in player_state.grid.get_occupied_slots():
			var structure_id: StringName = player_state.grid.get_slot(slot_index).structure_id
			counts[structure_id] = int(counts.get(structure_id, 0)) + 1
		_current.structures[player_id] = counts
		var unlocked: int = 0
		for plot_index: int in GridState.PLOT_COUNT:
			if player_state.grid.is_plot_unlocked(plot_index):
				unlocked += 1
		_current.plots_unlocked[player_id] = unlocked
	if GameManager.is_match_running():
		GameManager.end_match(MatchTypes.NO_PLAYER)


func _on_unit_hp_changed(_unit: CharacterBody2D, delta: float) -> void:
	if _current != null and delta < 0.0 and _current.first_combat < 0.0:
		_current.first_combat = GameManager.match_state.match_time


func _on_castle_damaged(_player_id: int, _hp: float, _max_hp: float) -> void:
	if _current != null and _current.first_castle_hit < 0.0:
		_current.first_castle_hit = GameManager.match_state.match_time


func _on_unit_spawned(_unit: CharacterBody2D, team: int) -> void:
	if _current != null and MatchTypes.is_valid_player_id(team):
		_current.units_spawned[team] += 1


func _on_gold_changed(player_id: int, total: int) -> void:
	if _current == null:
		return
	var delta: int = total - _last_gold[player_id]
	if delta > 0:
		_current.earned[player_id] += delta
	_last_gold[player_id] = total
	_current.peak_gold[player_id] = maxi(_current.peak_gold[player_id], total)


# --- Informe -------------------------------------------------------------------------

## Convierte los resultados en filas simples (Dictionary) para el informe.
func results_to_rows(results: Array[MatchResult]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for result: MatchResult in results:
		rows.append({
			"seed": result.seed_value,
			"bottom": result.profiles[0],
			"top": result.profiles[1],
			"winner": result.winner,
			"timed_out": result.timed_out,
			"duration": result.duration,
			"first_combat": result.first_combat,
			"first_castle_hit": result.first_castle_hit,
			"castle_bottom": result.castle_hp_ratio[0],
			"castle_top": result.castle_hp_ratio[1],
			"earned_bottom": result.earned[0],
			"earned_top": result.earned[1],
			"peak_gold_bottom": result.peak_gold[0],
			"peak_gold_top": result.peak_gold[1],
			"units_bottom": result.units_spawned[0],
			"units_top": result.units_spawned[1],
			"army_bottom": result.army_seconds[0],
			"army_top": result.army_seconds[1],
			"structures_bottom": result.structures[0],
			"structures_top": result.structures[1],
			"plots_bottom": result.plots_unlocked[0],
			"plots_top": result.plots_unlocked[1],
		})
	return rows


func _write_csv(path: String, results: Array[MatchResult]) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("No se pudo escribir %s" % path)
		return
	file.store_line("seed,bottom,top,winner,timed_out,duration,first_combat,first_castle_hit,castle_bottom,castle_top,earned_bottom,earned_top,units_bottom,units_top")
	for result: MatchResult in results:
		file.store_line("%d,%s,%s,%d,%s,%.1f,%.1f,%.1f,%.2f,%.2f,%d,%d,%d,%d" % [
			result.seed_value, result.profiles[0], result.profiles[1], result.winner, result.timed_out,
			result.duration, result.first_combat, result.first_castle_hit,
			result.castle_hp_ratio[0], result.castle_hp_ratio[1],
			result.earned[0], result.earned[1], result.units_spawned[0], result.units_spawned[1]])
	file.close()
