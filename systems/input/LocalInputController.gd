class_name LocalInputController
extends Node2D
## Traduce toques del jugador local sobre el mundo en selección (estado de UI)
## o en comandos. No aplica reglas: todo pasa por GameManager.submit_command.
##
## Tap = pulsar y soltar sin moverse más de TAP_MAX_DISTANCE (si se mueve,
## es un arrastre de cámara). Usa _unhandled_input para que la UI tenga prioridad.
## En builds de depuración también permite interactuar con el grid rival (source DEBUG).

const TAP_MAX_DISTANCE: float = 24.0

var selected_player_id: int = MatchTypes.NO_PLAYER
var selected_slot: int = -1

var _grids: Array[GridManager] = []
var _press_position: Vector2 = Vector2.ZERO
var _is_pressed: bool = false


func _ready() -> void:
	EventBus.partida_iniciada.connect(_on_partida_iniciada)


func register_grid(grid: GridManager) -> void:
	if not _grids.has(grid):
		_grids.append(grid)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventScreenTouch:
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch.index != 0:
		return
	if touch.pressed:
		_is_pressed = true
		_press_position = touch.position
		return
	if not _is_pressed:
		return
	_is_pressed = false
	if touch.position.distance_to(_press_position) <= TAP_MAX_DISTANCE:
		handle_tap(screen_to_world(touch.position))
		get_viewport().set_input_as_handled()


func screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position


## Público para poder probarlo sin simular eventos de input.
func handle_tap(world_position: Vector2) -> void:
	for grid: GridManager in _grids:
		var plot_index: int = grid.get_plot_index_at(world_position)
		if plot_index < 0:
			continue
		if not _can_interact(grid.player_id):
			return
		var state: GridState = grid.get_state()
		if state != null and not state.is_plot_unlocked(plot_index):
			GameManager.submit_command(UnlockPlotCommand.new(grid.player_id, plot_index, _source_for(grid.player_id)))
			return
		select_slot(grid.player_id, grid.get_slot_index_at(world_position))
		return
	select_slot(MatchTypes.NO_PLAYER, -1)


func select_slot(player_id: int, slot_index: int) -> void:
	if slot_index < 0:
		player_id = MatchTypes.NO_PLAYER
	selected_player_id = player_id
	selected_slot = slot_index
	EventBus.slot_seleccionado.emit(player_id, slot_index)


## El grid propio siempre; el rival solo en builds de depuración.
func _can_interact(player_id: int) -> bool:
	return player_id == GameManager.local_player_id or OS.is_debug_build()


func _source_for(player_id: int) -> GameCommand.Source:
	if player_id == GameManager.local_player_id:
		return GameCommand.Source.LOCAL_PLAYER
	return GameCommand.Source.DEBUG


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	select_slot(MatchTypes.NO_PLAYER, -1)
