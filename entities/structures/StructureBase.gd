class_name StructureBase
extends Node2D
## Estructura construida en un slot.
##
## GridManager la crea (subclase según StructureData.kind), fija su nivel
## (= nº de estructuras de este tipo del jugador) y llama a simulate() en
## orden de slot, solo en la autoridad. No tiene _physics_process propio.
##
## Ciclo de producción común: cada get_production_interval() segundos llama
## a _on_production_cycle(). Farm y Spawner lo usan; Tower tiene su propio
## ciclo de disparo. Un intervalo de 0 significa "sin ciclo".

const PROGRESS_BAR_HEIGHT: float = 8.0
## Cambio mínimo de progreso para redibujar la barra (evita redibujar cada tick).
const PROGRESS_REDRAW_STEP: float = 0.02

var building_id: int = 0
var owner_id: int = MatchTypes.NO_PLAYER
var data: StructureData = null
var slot_index: int = -1
var level: int = 1
var body_size: Vector2 = Vector2(120.0, 120.0)
var grid: GridManager = null
## Segundos acumulados hacia el próximo ciclo de producción.
var production_timer: float = 0.0

var _label: Label = null
var _sprite: AnimatedSprite2D = null
var _drawn_progress: float = -1.0


func setup(p_building_id: int, p_owner_id: int, p_data: StructureData, p_slot_index: int, p_body_size: Vector2, p_grid: GridManager) -> void:
	building_id = p_building_id
	owner_id = p_owner_id
	data = p_data
	slot_index = p_slot_index
	body_size = p_body_size
	grid = p_grid
	name = "Structure_%d" % building_id
	_create_visuals()


func set_level(new_level: int) -> void:
	level = data.clamp_level(new_level) if data != null else maxi(1, new_level)
	_update_label()


## Un paso de simulación. Lo llama GridManager (nunca el propio nodo).
func simulate(delta: float) -> void:
	var interval: float = get_production_interval()
	if interval <= 0.0:
		return
	production_timer += delta
	while production_timer >= interval:
		production_timer -= interval
		_on_production_cycle()
	_refresh_progress(production_timer / interval)


## Segundos entre ciclos de producción. 0 = sin ciclo (la base no produce).
func get_production_interval() -> float:
	return 0.0


## Efecto de un ciclo de producción. Solo se llama si el intervalo es > 0,
## así que toda subclase que defina un intervalo debe implementarlo.
func _on_production_cycle() -> void:
	push_error("StructureBase '%s': _on_production_cycle no implementado" % (data.id if data != null else &"?"))


func get_lane() -> LaneManager:
	return grid.lane if grid != null else null


func get_progress() -> float:
	var interval: float = get_production_interval()
	return clampf(production_timer / interval, 0.0, 1.0) if interval > 0.0 else 0.0


func to_dict() -> Dictionary:
	return {
		"building_id": building_id,
		"owner_id": owner_id,
		"structure_id": data.id if data != null else &"",
		"slot_index": slot_index,
		"level": level,
		"production_timer": production_timer,
	}


# --- Visual ----------------------------------------------------------------

func _refresh_progress(progress: float) -> void:
	if absf(progress - _drawn_progress) >= PROGRESS_REDRAW_STEP or progress < _drawn_progress:
		_drawn_progress = progress
		queue_redraw()


func _create_visuals() -> void:
	if data == null:
		return
	if data.sprite_frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = data.sprite_frames
		if data.sprite_frames.has_animation(data.anim_idle):
			_sprite.play(data.anim_idle)
		add_child(_sprite)
	_label = Label.new()
	_label.position = -body_size * 0.5
	_label.size = body_size
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_constant_override("outline_size", 8)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_label)
	ViewOrientation.orient(_label)
	_update_label()
	queue_redraw()


func _update_label() -> void:
	if _label == null or data == null:
		return
	var short_name: String = tr(data.short_label) if data.short_label != "" else tr(data.display_name)
	_label.text = "%s\nLv%d" % [short_name, level]


func _draw() -> void:
	if data == null:
		return
	var rect: Rect2 = Rect2(-body_size * 0.5, body_size)
	if _sprite == null:
		draw_rect(rect, data.color)
	draw_rect(rect, MatchTypes.team_color(owner_id), false, 6.0)
	if get_production_interval() > 0.0:
		var bar: Rect2 = Rect2(rect.position.x + 6.0, rect.end.y - PROGRESS_BAR_HEIGHT - 6.0, rect.size.x - 12.0, PROGRESS_BAR_HEIGHT)
		draw_rect(bar, Color(0.0, 0.0, 0.0, 0.6))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * get_progress(), bar.size.y)), Color(1.0, 1.0, 1.0, 0.9))
