class_name AIController
extends Node
## Controla un reino en VS AI usando EXACTAMENTE las mismas vías que un
## jugador humano: lee su oro, su tienda, su grid y el campo de batalla
## (información pública) y envía GameCommands con source AI al
## CommandProcessor, que los valida igual que los del jugador.
## Nunca modifica estado directamente.

## Orden de búsqueda de slots (índices de plot y de slot dentro del plot).
## Torres: fila delantera de los plots delanteros. Resto: detrás primero.
const TOWER_PLOT_ORDER: Array[int] = [0, 1, 2]
const TOWER_SLOT_ORDER: Array[int] = [0, 1]
const BUILD_PLOT_ORDER: Array[int] = [4, 3, 5, 1, 0, 2]
const BUILD_SLOT_ORDER: Array[int] = [2, 3, 0, 1]

@export var enabled: bool = true
## Segundos entre decisiones (tiempo de reacción).
@export var think_interval: float = 1.0
## Multiplicador de ingresos de este rival (dificultad). 1.0 = sin ventaja.
@export var income_multiplier: float = 1.0

var player_id: int = MatchTypes.PLAYER_TOP
var strategy: AIStrategy = RuleBasedStrategy.new()
var draft: DraftManager = null
var grid: GridManager = null
var lane: LaneManager = null

var _think_timer: float = 0.0


func _ready() -> void:
	add_to_group(&"ai_controller")
	EventBus.partida_iniciada.connect(_on_partida_iniciada)


func setup(p_player_id: int, p_draft: DraftManager, p_grid: GridManager, p_lane: LaneManager) -> void:
	player_id = p_player_id
	draft = p_draft
	grid = p_grid
	lane = p_lane


func _physics_process(delta: float) -> void:
	simulate_step(delta)


func simulate_step(delta: float) -> void:
	if not enabled or delta <= 0.0 or not GameManager.is_authority() or not GameManager.is_match_running():
		return
	if GameManager.game_mode != MatchTypes.GameMode.VS_AI and GameManager.game_mode != MatchTypes.GameMode.SPECTATE:
		return
	_think_timer += delta
	if _think_timer >= think_interval:
		_think_timer -= think_interval
		think()


## Un turno de decisión. Devuelve true si se ejecutó un comando.
func think() -> bool:
	if strategy == null or draft == null or grid == null or lane == null:
		return false
	var command: GameCommand = strategy.choose_command(self)
	if command == null:
		return false
	command.player_id = player_id
	command.source = GameCommand.Source.AI
	return GameManager.submit_command(command)


# --- Consultas de solo lectura para las estrategias ------------------------------

func get_gold() -> int:
	return EconomyManager.get_gold(player_id)


func get_offer() -> Array[CardData]:
	return draft.get_offer(player_id)


func get_reroll_cost() -> int:
	return draft.get_reroll_cost(player_id)


func get_match_time() -> float:
	return GameManager.match_state.match_time if GameManager.match_state != null else 0.0


func count_structures(structure_id: StringName) -> int:
	return grid.get_state().count_structures(structure_id)


func count_structures_with_tag(tag: StringName) -> int:
	return grid.count_structures_with_tag(tag)


## Enemigos vivos dentro de mi mitad del carril.
func get_threat() -> int:
	var threat: int = 0
	var my_half: Rect2 = lane.get_deploy_rect(player_id)
	for unit: UnitBase in lane.get_alive_units():
		if unit.team != player_id and my_half.has_point(unit.global_position):
			threat += 1
	return threat


## Tropas que puede tener vivas según el nivel de sus granjas.
func get_unit_cap() -> int:
	return lane.get_unit_cap(player_id)


func get_army_size() -> int:
	return lane.get_alive_count(player_id)


## Punto de despliegue para cartas de unidad: centro de mi mitad del carril.
func get_deploy_point() -> Vector2:
	return lane.get_deploy_rect(player_id).get_center()


## Slot libre para construir. Torres: solo fila delantera de los plots
## delanteros (la trasera no alcanza el carril). Resto: detrás primero, para
## dejar la fila delantera a las torres. -1 si no hay.
func find_build_slot(for_tower: bool) -> int:
	var state: GridState = grid.get_state()
	var plot_order: Array[int] = TOWER_PLOT_ORDER if for_tower else BUILD_PLOT_ORDER
	var local_order: Array[int] = TOWER_SLOT_ORDER if for_tower else BUILD_SLOT_ORDER
	for plot_index: int in plot_order:
		if not state.is_plot_unlocked(plot_index):
			continue
		for local_index: int in local_order:
			var slot_index: int = GridState.first_slot_of_plot(plot_index) + local_index
			if state.is_slot_free(slot_index):
				return slot_index
	return -1


## Plot bloqueado más barato (opcionalmente solo delanteros). -1 si no hay.
func find_cheapest_locked_plot(front_only: bool) -> int:
	var state: GridState = grid.get_state()
	var rules: GameRules = GameManager.get_rules()
	var best: int = -1
	for plot_index: int in GridState.PLOT_COUNT:
		if state.is_plot_unlocked(plot_index) or (front_only and plot_index > 2):
			continue
		if best < 0 or rules.get_plot_cost(plot_index) < rules.get_plot_cost(best):
			best = plot_index
	return best


func get_plot_cost(plot_index: int) -> int:
	return GameManager.get_rules().get_plot_cost(plot_index)


## Azar controlado de la IA (desempates), derivado de la semilla de partida.
func get_rng() -> RandomNumberGenerator:
	return GameManager.match_state.random.get_stream(MatchRandom.STREAM_AI, player_id)


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	_think_timer = 0.0
	EconomyManager.set_income_multiplier(player_id, income_multiplier)
