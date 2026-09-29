class_name GridManager
extends Node2D
## Sistema del grid de UN jugador (hay una instancia por player_id).
##
## Es el único que modifica el GridState de su jugador y mantiene los nodos
## (Plot, BuildingSlot, StructureBase) sincronizados con ese estado.
## No toca el oro: los comandos cobran/reembolsan vía EconomyManager y
## después llaman a build()/sell()/unlock().
##
## Orden de plots y slots (desde el punto de vista del dueño):
##   plots 0-2 = fila delantera (junto al castillo/carril), 3-5 = fila trasera,
##   columnas de izquierda a derecha en pantalla. Dentro de un plot, slots
##   0-1 delante y 2-3 detrás. El player 1 está espejado en vertical.

const PLOT_COLUMNS: int = 3
const PLOT_ROWS: int = 2
const SLOT_COLUMNS: int = 2
const SLOT_ROWS: int = 2
## Fracción del slot que ocupa el cuerpo de la estructura (deja ver el borde de selección).
const STRUCTURE_FILL: float = 0.86

@export var player_id: int = MatchTypes.PLAYER_BOTTOM
@export var grid_size: Vector2 = Vector2(1020.0, 700.0)
@export var plot_gap: float = 20.0
@export var plot_padding: float = 12.0
@export var slot_gap: float = 10.0

## Carril al que las estructuras envían unidades y proyectiles (lo asigna Main).
var lane: LaneManager = null

var _plots: Array[Plot] = []
var _slots: Array[BuildingSlot] = []


func _ready() -> void:
	# Las estructuras simulan antes que el carril en cada tick, para que las
	# unidades producidas en este tick se muevan en el mismo tick en ambos bandos.
	process_physics_priority = -10
	_create_nodes()
	EventBus.partida_iniciada.connect(_on_partida_iniciada)
	EventBus.slot_seleccionado.connect(_on_slot_seleccionado)
	_sync_from_state()


func _physics_process(delta: float) -> void:
	simulate_step(delta)
	if not GameManager.is_authority() and GameManager.is_match_running():
		for slot: BuildingSlot in _slots:
			if slot.structure != null:
				slot.structure.simulate_visual(delta)


## Temporizadores de producción por slot (0 en huecos vacíos o sin ciclo), para
## replicarlos a los clientes. Redondeados: solo alimentan una barra visual.
func get_production_timers() -> Array[float]:
	var timers: Array[float] = []
	for slot: BuildingSlot in _slots:
		timers.append(snappedf(slot.structure.production_timer, 0.01) if slot.structure != null else 0.0)
	return timers


## Solo clientes online: aplica los temporizadores recibidos del servidor.
func apply_production_timers(timers: Array) -> void:
	for slot_index: int in mini(timers.size(), _slots.size()):
		var structure: StructureBase = _slots[slot_index].structure
		if structure != null:
			structure.set_production_timer(float(timers[slot_index]))


## Simula las estructuras en orden de slot. Solo en la autoridad.
func simulate_step(delta: float) -> void:
	if delta <= 0.0 or not GameManager.is_authority() or not GameManager.is_match_running():
		return
	for slot: BuildingSlot in _slots:
		if slot.structure != null:
			slot.structure.simulate(delta)


# --- Estado -----------------------------------------------------------------

func get_state() -> GridState:
	var player_state: PlayerState = GameManager.get_player_state(player_id)
	return player_state.grid if player_state != null else null


func get_slot_node(slot_index: int) -> BuildingSlot:
	return _slots[slot_index] if GridState.is_valid_slot(slot_index) else null


func get_slot_count() -> int:
	return _slots.size()


func get_structure_at(slot_index: int) -> StructureBase:
	if not GridState.is_valid_slot(slot_index):
		return null
	return _slots[slot_index].structure


func get_invested_gold(slot_index: int) -> int:
	var state: GridState = get_state()
	if state == null or not state.is_valid_slot(slot_index):
		return 0
	return state.get_slot(slot_index).invested_gold


## Nivel de un tipo de estructura = cuántas tiene construidas el jugador (1..max_level).
func get_structure_level(structure: StructureData) -> int:
	var state: GridState = get_state()
	if state == null or structure == null:
		return 0
	return structure.clamp_level(state.count_structures(structure.id))


## Menor building_id entre las estructuras de ese tipo del jugador (0 si no hay).
func get_first_building_id(structure_id: StringName) -> int:
	var state: GridState = get_state()
	if state == null:
		return 0
	var first: int = 0
	for slot_index: int in state.get_occupied_slots():
		var slot_state: GridState.SlotState = state.get_slot(slot_index)
		if slot_state.structure_id == structure_id and (first == 0 or slot_state.building_id < first):
			first = slot_state.building_id
	return first


func count_structures_with_tag(tag: StringName) -> int:
	var state: GridState = get_state()
	return state.count_structures_with_tag(tag, GameManager.database) if state != null else 0


# --- Validación (devuelve "" si es válido o el motivo del rechazo) ---------

func can_build(slot_index: int, structure: StructureData) -> String:
	var state: GridState = get_state()
	if state == null:
		return Reason.make("No hay partida")
	if structure == null:
		return Reason.make("Estructura desconocida")
	if not GridState.is_valid_slot(slot_index):
		return Reason.make("Slot inválido")
	if not state.is_plot_unlocked(GridState.plot_of_slot(slot_index)):
		return Reason.make("Plot bloqueado")
	if not state.is_slot_free(slot_index):
		return Reason.make("Slot ocupado")
	if state.count_structures(structure.id) >= structure.max_level:
		return Reason.make("Máximo de %s alcanzado (Lv%d)", [structure.display_name, structure.max_level])
	return ""


func can_sell(slot_index: int) -> String:
	var state: GridState = get_state()
	if state == null:
		return Reason.make("No hay partida")
	if not GridState.is_valid_slot(slot_index):
		return Reason.make("Slot inválido")
	if state.is_slot_free(slot_index):
		return Reason.make("No hay estructura que vender")
	return ""


func can_unlock(plot_index: int) -> String:
	var state: GridState = get_state()
	if state == null:
		return Reason.make("No hay partida")
	if not GridState.is_valid_plot(plot_index):
		return Reason.make("Plot inválido")
	if state.is_plot_unlocked(plot_index):
		return Reason.make("Plot ya desbloqueado")
	return ""


# --- Mutaciones (solo desde comandos ya validados) --------------------------

func build(slot_index: int, structure: StructureData, invested_gold: int) -> StructureBase:
	var reason: String = can_build(slot_index, structure)
	if reason != "":
		push_error("GridManager.build sin validar: %s" % reason)
		return null
	var building_id: int = GameManager.match_state.allocate_entity_id()
	get_state().place_structure(slot_index, structure.id, building_id, invested_gold)
	var node: StructureBase = _spawn_structure_node(slot_index, structure, building_id)
	_refresh_levels(structure)
	EventBus.estructura_construida.emit(player_id, slot_index, structure, get_structure_level(structure))
	return node


## Libera el slot y destruye la estructura. Devuelve el oro que se invirtió.
func sell(slot_index: int, refund: int) -> int:
	var reason: String = can_sell(slot_index)
	if reason != "":
		push_error("GridManager.sell sin validar: %s" % reason)
		return 0
	var state: GridState = get_state()
	var invested: int = state.get_slot(slot_index).invested_gold
	var structure: StructureData = GameManager.database.get_structure(state.get_slot(slot_index).structure_id)
	state.clear_slot(slot_index)
	var node: StructureBase = _slots[slot_index].detach_structure()
	if node != null:
		node.queue_free()
	if structure != null:
		_refresh_levels(structure)
	EventBus.estructura_vendida.emit(player_id, slot_index, refund)
	return invested


func unlock(plot_index: int) -> void:
	var reason: String = can_unlock(plot_index)
	if reason != "":
		push_error("GridManager.unlock sin validar: %s" % reason)
		return
	get_state().unlock_plot(plot_index)
	_refresh_plot(plot_index)
	EventBus.plot_desbloqueado.emit(player_id, plot_index)


# --- Geometría (coordenadas locales del grid salvo que se indique) ----------

func get_plot_size() -> Vector2:
	return Vector2(
		(grid_size.x - plot_gap * (PLOT_COLUMNS - 1)) / PLOT_COLUMNS,
		(grid_size.y - plot_gap * (PLOT_ROWS - 1)) / PLOT_ROWS)


func get_slot_size() -> Vector2:
	var plot_size: Vector2 = get_plot_size()
	return Vector2(
		(plot_size.x - plot_padding * 2.0 - slot_gap * (SLOT_COLUMNS - 1)) / SLOT_COLUMNS,
		(plot_size.y - plot_padding * 2.0 - slot_gap * (SLOT_ROWS - 1)) / SLOT_ROWS)


func get_plot_rect(plot_index: int) -> Rect2:
	@warning_ignore("integer_division")
	var front_row: int = plot_index / PLOT_COLUMNS
	var column: int = _screen_column(plot_index % PLOT_COLUMNS, PLOT_COLUMNS)
	var plot_size: Vector2 = get_plot_size()
	var screen_row: int = _screen_row(front_row, PLOT_ROWS)
	return Rect2(Vector2(column * (plot_size.x + plot_gap), screen_row * (plot_size.y + plot_gap)), plot_size)


func get_slot_rect(slot_index: int) -> Rect2:
	var plot_rect: Rect2 = get_plot_rect(GridState.plot_of_slot(slot_index))
	var local_index: int = slot_index % GridState.SLOTS_PER_PLOT
	@warning_ignore("integer_division")
	var front_row: int = local_index / SLOT_COLUMNS
	var column: int = _screen_column(local_index % SLOT_COLUMNS, SLOT_COLUMNS)
	var slot_size: Vector2 = get_slot_size()
	var screen_row: int = _screen_row(front_row, SLOT_ROWS)
	var offset: Vector2 = Vector2(plot_padding, plot_padding) + Vector2(column * (slot_size.x + slot_gap), screen_row * (slot_size.y + slot_gap))
	return Rect2(plot_rect.position + offset, slot_size)


func get_slot_world_position(slot_index: int) -> Vector2:
	return to_global(get_slot_rect(slot_index).get_center())


func get_plot_index_at(world_position: Vector2) -> int:
	var local_position: Vector2 = to_local(world_position)
	for plot_index: int in GridState.PLOT_COUNT:
		if get_plot_rect(plot_index).has_point(local_position):
			return plot_index
	return -1


func get_slot_index_at(world_position: Vector2) -> int:
	var local_position: Vector2 = to_local(world_position)
	for slot_index: int in GridState.SLOT_COUNT:
		if get_slot_rect(slot_index).has_point(local_position):
			return slot_index
	return -1


## Slot en el que se construiría al soltar una carta en `world_position`:
## el slot libre bajo el puntero o, si no, el primer slot libre del plot.
## -1 si el plot está bloqueado, lleno o el punto está fuera del grid.
func resolve_drop_slot(world_position: Vector2) -> int:
	var state: GridState = get_state()
	var plot_index: int = get_plot_index_at(world_position)
	if state == null or plot_index < 0 or not state.is_plot_unlocked(plot_index):
		return -1
	var slot_index: int = get_slot_index_at(world_position)
	if slot_index >= 0 and state.is_slot_free(slot_index):
		return slot_index
	return state.find_first_free_slot_in_plot(plot_index)


# --- Nodos ------------------------------------------------------------------

## Player 1 está reflejado respecto al centro (filas y columnas): con su
## vista girada 180° ve su reino exactamente igual que el player 0 el suyo.
func _screen_column(column: int, columns: int) -> int:
	return column if player_id == MatchTypes.PLAYER_BOTTOM else columns - 1 - column


func _screen_row(front_row: int, rows: int) -> int:
	# Player 0 (abajo) tiene la fila delantera arriba; player 1, abajo.
	return front_row if player_id == MatchTypes.PLAYER_BOTTOM else rows - 1 - front_row


func _create_nodes() -> void:
	var plot_size: Vector2 = get_plot_size()
	var slot_size: Vector2 = get_slot_size()
	for plot_index: int in GridState.PLOT_COUNT:
		var plot: Plot = Plot.new()
		plot.setup(plot_index, player_id, plot_size)
		plot.position = get_plot_rect(plot_index).position
		add_child(plot)
		_plots.append(plot)
	for slot_index: int in GridState.SLOT_COUNT:
		var slot: BuildingSlot = BuildingSlot.new()
		slot.setup(slot_index, player_id, slot_size)
		var plot: Plot = _plots[GridState.plot_of_slot(slot_index)]
		slot.position = get_slot_rect(slot_index).position - plot.position
		plot.add_child(slot)
		_slots.append(slot)


func _spawn_structure_node(slot_index: int, structure: StructureData, building_id: int) -> StructureBase:
	var node: StructureBase = _create_structure_for_kind(structure.kind)
	node.setup(building_id, player_id, structure, slot_index, get_slot_size() * STRUCTURE_FILL, self)
	_slots[slot_index].attach_structure(node)
	return node


func _create_structure_for_kind(kind: StructureData.Kind) -> StructureBase:
	match kind:
		StructureData.Kind.FARM:
			return FarmStructure.new()
		StructureData.Kind.SPAWNER:
			return SpawnerStructure.new()
		StructureData.Kind.TOWER:
			return TowerStructure.new()
	return StructureBase.new()


func _refresh_levels(structure: StructureData) -> void:
	var level: int = get_structure_level(structure)
	for slot: BuildingSlot in _slots:
		if slot.structure != null and slot.structure.data == structure:
			slot.structure.set_level(level)


func _refresh_plot(plot_index: int) -> void:
	var state: GridState = get_state()
	var rules: GameRules = GameManager.get_rules()
	var locked: bool = state == null or not state.is_plot_unlocked(plot_index)
	var cost: int = rules.get_plot_cost(plot_index) if rules != null else 0
	_plots[plot_index].set_lock_state(locked, cost)


## Reconstruye todos los nodos a partir del GridState (inicio de partida y,
## en el futuro, reconexión online).
func _sync_from_state() -> void:
	for slot: BuildingSlot in _slots:
		var old: StructureBase = slot.detach_structure()
		if old != null:
			old.queue_free()
		slot.set_selected(false)
	for plot_index: int in GridState.PLOT_COUNT:
		_refresh_plot(plot_index)
	var state: GridState = get_state()
	if state == null or GameManager.database == null:
		return
	var touched: Array[StructureData] = []
	for slot_index: int in state.get_occupied_slots():
		var slot_state: GridState.SlotState = state.get_slot(slot_index)
		var structure: StructureData = GameManager.database.get_structure(slot_state.structure_id)
		if structure == null:
			continue
		_spawn_structure_node(slot_index, structure, slot_state.building_id)
		if not touched.has(structure):
			touched.append(structure)
	for structure: StructureData in touched:
		_refresh_levels(structure)


## Reconstruye los nodos desde el estado (clientes online tras un snapshot).
func resync_from_state() -> void:
	_sync_from_state()


## Marca los slots donde se podría construir `structure` (arrastre de carta).
func show_build_hints(structure: StructureData, affordable: bool = true) -> void:
	for slot: BuildingSlot in _slots:
		var valid: bool = affordable and structure != null and can_build(slot.slot_index, structure) == ""
		slot.set_hint(BuildingSlot.Hint.VALID if valid else BuildingSlot.Hint.NONE)


## Marca el slot bajo el puntero como destino válido o inválido.
func set_hover_hint(slot_index: int, valid: bool) -> void:
	for slot: BuildingSlot in _slots:
		if slot.slot_index == slot_index:
			slot.set_hint(BuildingSlot.Hint.VALID if valid else BuildingSlot.Hint.INVALID)


func clear_build_hints() -> void:
	for slot: BuildingSlot in _slots:
		slot.set_hint(BuildingSlot.Hint.NONE)


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	_sync_from_state()


func _on_slot_seleccionado(selected_player_id: int, slot_index: int) -> void:
	for slot: BuildingSlot in _slots:
		slot.set_selected(selected_player_id == player_id and slot.slot_index == slot_index)
