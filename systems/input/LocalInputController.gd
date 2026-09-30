class_name LocalInputController
extends Node2D
## Traduce la interacción del jugador local sobre el mundo en selección
## (estado de UI) o en comandos. No aplica reglas: todo pasa por
## GameManager.submit_command, así jugador, IA y red comparten validación.
##
## - Tap (pulsar y soltar sin moverse más de TAP_MAX_DISTANCE): seleccionar
##   slot, comprar plot bloqueado o, en modo martillo, vender.
## - Soltar carta (lo inicia la tienda): estructura → plot bajo el puntero;
##   unidades → posición en la mitad propia del carril.
## En builds de depuración también permite interactuar con el grid rival (DEBUG).

signal hammer_mode_changed(active: bool)

const TAP_MAX_DISTANCE: float = 24.0
const DEPLOY_ZONE_COLOR: Color = Color(0.3, 1.0, 0.4, 0.14)
const DEPLOY_ZONE_BORDER: Color = Color(0.3, 1.0, 0.4, 0.6)

var selected_player_id: int = MatchTypes.NO_PLAYER
var selected_slot: int = -1
var hammer_mode: bool = false
## Mientras se arrastra una carta, los taps del mundo se ignoran.
var input_blocked: bool = false
var lane: LaneManager = null

var _grids: Array[GridManager] = []
var _mod_views: Array[ModBuildingView] = []
var _press_position: Vector2 = Vector2.ZERO
var _is_pressed: bool = false
var _dragged_card: CardData = null
## Habilidad de castillo que se está arrastrando y dónde cae (coordenadas del mundo).
var _dragged_spell: SpellData = null
var _spell_drag_world: Vector2 = Vector2.ZERO


func _ready() -> void:
	EventBus.partida_iniciada.connect(_on_partida_iniciada)


func register_mod_view(view: ModBuildingView) -> void:
	if not _mod_views.has(view):
		_mod_views.append(view)


func register_grid(grid: GridManager) -> void:
	if not _grids.has(grid):
		_grids.append(grid)


func _unhandled_input(event: InputEvent) -> void:
	if input_blocked or not event is InputEventScreenTouch:
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


# --- Taps ----------------------------------------------------------------------

## Público para poder probarlo sin simular eventos de input.
func handle_tap(world_position: Vector2) -> void:
	for view: ModBuildingView in _mod_views:
		if view.contains_point(world_position):
			view.toggle_info()
			return
	for grid: GridManager in _grids:
		var plot_index: int = grid.get_plot_index_at(world_position)
		if plot_index < 0:
			continue
		if not _can_interact(grid.player_id):
			return
		var slot_index: int = grid.get_slot_index_at(world_position)
		if hammer_mode:
			if slot_index >= 0 and grid.get_structure_at(slot_index) != null:
				GameManager.submit_command(SellCommand.new(grid.player_id, slot_index, _source_for(grid.player_id)))
				set_hammer_mode(false)
			return
		var state: GridState = grid.get_state()
		if state != null and not state.is_plot_unlocked(plot_index):
			GameManager.submit_command(UnlockPlotCommand.new(grid.player_id, plot_index, _source_for(grid.player_id)))
			return
		select_slot(grid.player_id, slot_index)
		return
	select_slot(MatchTypes.NO_PLAYER, -1)


func select_slot(player_id: int, slot_index: int) -> void:
	if slot_index < 0:
		player_id = MatchTypes.NO_PLAYER
	selected_player_id = player_id
	selected_slot = slot_index
	EventBus.slot_seleccionado.emit(player_id, slot_index)


func set_hammer_mode(active: bool) -> void:
	if hammer_mode == active:
		return
	hammer_mode = active
	hammer_mode_changed.emit(active)


# --- Cartas --------------------------------------------------------------------

func begin_card_drag(card: CardData) -> void:
	_dragged_card = card
	input_blocked = true
	_is_pressed = false
	set_hammer_mode(false)
	queue_redraw()
	_refresh_build_hints()


## Resalta el slot donde se construiría la estructura arrastrada: verde si es
## un destino válido y asequible, rojo si el slot bajo el puntero no lo es.
func update_card_drag(screen_position: Vector2) -> void:
	if _dragged_card == null or _dragged_card.card_type != CardData.CardType.STRUCTURE:
		return
	var grid: GridManager = _get_local_grid()
	if grid == null:
		return
	var world_position: Vector2 = screen_to_world(screen_position)
	var drop_slot: int = grid.resolve_drop_slot(world_position)
	select_slot(grid.player_id, drop_slot)
	_refresh_build_hints()
	if drop_slot >= 0:
		grid.set_hover_hint(drop_slot, _can_afford_dragged_card())
	else:
		var hovered: int = grid.get_slot_index_at(world_position)
		if hovered >= 0:
			select_slot(grid.player_id, hovered)
			grid.set_hover_hint(hovered, false)


## Termina el arrastre. Si no se canceló, envía el PlayCardCommand
## correspondiente; la autoridad decide si es válido.
func end_card_drag(offer_index: int, card: CardData, screen_position: Vector2, cancelled: bool) -> void:
	_dragged_card = null
	input_blocked = false
	queue_redraw()
	select_slot(MatchTypes.NO_PLAYER, -1)
	_clear_build_hints()
	if cancelled or card == null:
		return
	play_card_at(offer_index, card, screen_to_world(screen_position))


## Público para poder probarlo sin simular arrastres.
func play_card_at(offer_index: int, card: CardData, world_position: Vector2) -> void:
	var player_id: int = GameManager.local_player_id
	var slot_index: int = -1
	if card.card_type == CardData.CardType.STRUCTURE:
		var grid: GridManager = _get_local_grid()
		slot_index = grid.resolve_drop_slot(world_position) if grid != null else -1
	GameManager.submit_command(PlayCardCommand.new(player_id, offer_index, card.id, slot_index, world_position))


func _draw() -> void:
	if _dragged_spell != null and lane != null:
		var spell_zone: Rect2 = lane.get_deploy_rect(GameManager.local_player_id)
		var inside: bool = spell_zone.has_point(_spell_drag_world)
		draw_rect(spell_zone, DEPLOY_ZONE_COLOR)
		draw_rect(spell_zone, DEPLOY_ZONE_BORDER, false, 4.0)
		var aim: Color = _dragged_spell.color if inside else Color(1.0, 0.3, 0.25)
		var aim_radius: float = _dragged_spell.radius if _dragged_spell.kind != SpellData.Kind.MILITIA else 110.0
		draw_circle(_spell_drag_world, aim_radius, Color(aim, 0.16))
		draw_arc(_spell_drag_world, aim_radius, 0.0, TAU, 48, Color(aim, 0.9), 5.0)
		return
	if _dragged_card == null or _dragged_card.card_type != CardData.CardType.DIRECT_UNIT or lane == null:
		return
	var zone: Rect2 = lane.get_deploy_rect(GameManager.local_player_id)
	draw_rect(zone, DEPLOY_ZONE_COLOR)
	draw_rect(zone, DEPLOY_ZONE_BORDER, false, 4.0)


# --- Habilidades de castillo ------------------------------------------------------

func begin_spell_drag(spell: SpellData) -> void:
	_dragged_spell = spell
	input_blocked = true
	_is_pressed = false
	set_hammer_mode(false)
	queue_redraw()


func update_spell_drag(screen_position: Vector2) -> void:
	_spell_drag_world = screen_to_world(screen_position)
	queue_redraw()


## Termina el arrastre; si no se canceló, envía el CastSpellCommand (la autoridad valida).
func end_spell_drag(spell: SpellData, screen_position: Vector2, cancelled: bool) -> void:
	_dragged_spell = null
	input_blocked = false
	queue_redraw()
	if cancelled or spell == null:
		return
	cast_spell_at(spell, screen_to_world(screen_position))


## Público para poder probarlo sin simular arrastres.
func cast_spell_at(spell: SpellData, world_position: Vector2) -> void:
	GameManager.submit_command(CastSpellCommand.new(GameManager.local_player_id, spell.id, world_position))


# --- Interno -------------------------------------------------------------------

func _can_afford_dragged_card() -> bool:
	return _dragged_card != null and EconomyManager.has_gold(GameManager.local_player_id, EconomyManager.get_card_cost(GameManager.local_player_id, _dragged_card))


func _refresh_build_hints() -> void:
	var grid: GridManager = _get_local_grid()
	if grid == null or _dragged_card == null or _dragged_card.card_type != CardData.CardType.STRUCTURE:
		return
	grid.show_build_hints(_dragged_card.structure, _can_afford_dragged_card())


func _clear_build_hints() -> void:
	for grid: GridManager in _grids:
		grid.clear_build_hints()


func _get_local_grid() -> GridManager:
	for grid: GridManager in _grids:
		if grid.player_id == GameManager.local_player_id:
			return grid
	return null


## El grid propio siempre; el rival solo en builds de depuración.
func _can_interact(player_id: int) -> bool:
	return player_id == GameManager.local_player_id


func _source_for(player_id: int) -> GameCommand.Source:
	if player_id == GameManager.local_player_id:
		return GameCommand.Source.LOCAL_PLAYER
	return GameCommand.Source.DEBUG


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	set_hammer_mode(false)
	select_slot(MatchTypes.NO_PLAYER, -1)
