class_name FloatingTextLayer
extends Node2D
## Números flotantes y pulsos de feedback en coordenadas del mundo.
##
## Solo presentación: escucha el EventBus (daño/curación de unidades, daño al
## castillo, construir/vender/desbloquear) y dibuja todo en un único _draw
## para que cientos de golpes no creen cientos de nodos. Como reacciona a
## unidad_vida_cambiada, funciona igual en local, online y en repeticiones.

const MAX_ENTRIES: int = 64
const FONT_OUTLINE: int = 8
const RISE_SPEED: float = 90.0
const DAMAGE_LIFE: float = 0.8
const EVENT_LIFE: float = 1.3
## Colores según a quién le pasa: daño al bando propio / al rival, curación, oro.
const OWN_DAMAGE_COLOR: Color = Color(1.0, 0.35, 0.3)
const ENEMY_DAMAGE_COLOR: Color = Color(1.0, 0.9, 0.35)
const HEAL_COLOR: Color = Color(0.45, 1.0, 0.5)
const GOLD_COLOR: Color = Color(1.0, 0.82, 0.25)

class Entry:
	var position: Vector2 = Vector2.ZERO
	var text: String = ""
	var color: Color = Color.WHITE
	var font_size: int = 30
	var age: float = 0.0
	var life: float = 1.0
	var ring_radius: float = 0.0
	## Ancho del texto (medido una sola vez al crearlo).
	var width: float = 0.0

var _entries: Array[Entry] = []
var _grids: Dictionary[int, GridManager] = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _castle_hp: Dictionary[int, float] = {}


func _ready() -> void:
	z_index = 200
	_rng.randomize()
	EventBus.unidad_vida_cambiada.connect(_on_unidad_vida_cambiada)
	EventBus.castillo_danado.connect(_on_castillo_danado)
	EventBus.estructura_construida.connect(_on_estructura_construida)
	EventBus.estructura_vendida.connect(_on_estructura_vendida)
	EventBus.plot_desbloqueado.connect(_on_plot_desbloqueado)
	EventBus.partida_iniciada.connect(_on_partida_iniciada)


func setup(grids: Array[GridManager]) -> void:
	for grid: GridManager in grids:
		_grids[grid.player_id] = grid


## Texto libre del mundo (lo usan otros sistemas de presentación).
func add_text(world_position: Vector2, text: String, color: Color, font_size: int = 30, life: float = EVENT_LIFE) -> void:
	if GameManager.suppress_effects:
		return
	var entry: Entry = _new_entry(world_position, color, life)
	entry.text = text
	entry.font_size = font_size
	entry.width = ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func add_ring(world_position: Vector2, color: Color, radius: float = 90.0) -> void:
	if GameManager.suppress_effects:
		return
	var entry: Entry = _new_entry(world_position, color, 0.5)
	entry.ring_radius = radius


func get_entry_count() -> int:
	return _entries.size()


func _new_entry(world_position: Vector2, color: Color, life: float) -> Entry:
	if _entries.size() >= MAX_ENTRIES:
		_entries.remove_at(0)
	var entry: Entry = Entry.new()
	entry.position = world_position
	entry.color = color
	entry.life = life
	_entries.append(entry)
	return entry


func _process(delta: float) -> void:
	if _entries.is_empty():
		return
	var index: int = 0
	while index < _entries.size():
		var entry: Entry = _entries[index]
		entry.age += delta
		if entry.age >= entry.life:
			_entries.remove_at(index)
		else:
			index += 1
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var upright: float = PI if ViewOrientation.is_flipped() else 0.0
	for entry: Entry in _entries:
		var progress: float = entry.age / entry.life
		var alpha: float = 1.0 - clampf((progress - 0.55) / 0.45, 0.0, 1.0)
		if entry.ring_radius > 0.0:
			var color: Color = Color(entry.color, alpha * 0.9)
			draw_arc(entry.position, entry.ring_radius * (0.4 + 0.6 * progress), 0.0, TAU, 40, color, 6.0)
			continue
		var rise: float = RISE_SPEED * entry.age * (1.0 - progress * 0.5)
		# Pequeño "pop" al aparecer, con la escala del dibujo (no cambia el tamaño
		# de la fuente, así no se generan glifos nuevos a cada fotograma).
		var pop: float = 1.0 + 0.35 * maxf(0.0, 1.0 - progress * 6.0)
		var origin: Vector2 = entry.position + Vector2(0.0, -rise * (-1.0 if upright > 0.0 else 1.0))
		draw_set_transform(origin, upright, Vector2(pop, pop))
		var text_position: Vector2 = Vector2(-entry.width * 0.5, 0.0)
		draw_string_outline(font, text_position, entry.text, HORIZONTAL_ALIGNMENT_LEFT, -1, entry.font_size, FONT_OUTLINE, Color(0.0, 0.0, 0.0, alpha))
		draw_string(font, text_position, entry.text, HORIZONTAL_ALIGNMENT_LEFT, -1, entry.font_size, Color(entry.color, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Eventos ----------------------------------------------------------------------

func _on_unidad_vida_cambiada(unit: CharacterBody2D, delta: float) -> void:
	if GameManager.suppress_effects or not is_instance_valid(unit):
		return
	var amount: int = roundi(absf(delta))
	if amount < 1:
		return
	var offset: Vector2 = Vector2(_rng.randf_range(-24.0, 24.0), -(unit as UnitBase).body_radius - 26.0)
	if delta > 0.0:
		add_text(unit.global_position + offset, "+%d" % amount, HEAL_COLOR, 28, DAMAGE_LIFE)
		return
	var own_side: bool = (unit as UnitBase).team == GameManager.local_player_id
	var size: int = clampi(24 + amount / 3, 26, 52)
	add_text(unit.global_position + offset, str(amount), OWN_DAMAGE_COLOR if own_side else ENEMY_DAMAGE_COLOR, size, DAMAGE_LIFE)


func _on_castillo_danado(player_id: int, vida_actual: float, vida_maxima: float) -> void:
	var previous: float = _castle_hp.get(player_id, maxf(vida_maxima, vida_actual))
	_castle_hp[player_id] = vida_actual
	var lost: int = roundi(previous - vida_actual)
	if lost < 1 or GameManager.suppress_effects:
		return
	for node: Node in get_tree().get_nodes_in_group(&"castle"):
		var castle: Castle = node as Castle
		if castle != null and castle.owner_id == player_id:
			var jitter: Vector2 = Vector2(_rng.randf_range(-70.0, 70.0), _rng.randf_range(-30.0, 30.0))
			add_text(castle.global_position + jitter, "-%d" % lost, OWN_DAMAGE_COLOR, clampi(34 + lost / 6, 34, 70), DAMAGE_LIFE + 0.3)
			return


func _on_estructura_construida(player_id: int, slot_index: int, datos: StructureData, nivel: int) -> void:
	var grid: GridManager = _grids.get(player_id, null)
	if grid == null:
		return
	var position_in_world: Vector2 = grid.get_slot_world_position(slot_index)
	add_ring(position_in_world, MatchTypes.team_color(player_id).lightened(0.3))
	add_text(position_in_world + Vector2(0.0, -50.0), "%s Lv%d" % [tr(datos.display_name), nivel], Color.WHITE, 30)


func _on_estructura_vendida(player_id: int, slot_index: int, oro_devuelto: int) -> void:
	var grid: GridManager = _grids.get(player_id, null)
	if grid == null:
		return
	add_text(grid.get_slot_world_position(slot_index), "+%d" % oro_devuelto, GOLD_COLOR, 38)


func _on_plot_desbloqueado(player_id: int, plot_index: int) -> void:
	var grid: GridManager = _grids.get(player_id, null)
	if grid == null:
		return
	var center: Vector2 = grid.to_global(grid.get_plot_rect(plot_index).get_center())
	add_ring(center, GOLD_COLOR, 140.0)
	add_text(center, tr("¡Plot desbloqueado!"), GOLD_COLOR, 32)


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	_entries.clear()
	_castle_hp.clear()
