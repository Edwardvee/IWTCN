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

const PROGRESS_BAR_HEIGHT: float = 9.0
## Ancho del arte de referencia (px de mundo) que ocupa el hueco del slot.
const ART_REFERENCE_WIDTH: float = 126.0
## Los SVG se rasterizan a 2x.
const ART_RASTER_SCALE: float = 0.5
## El arte se centra visualmente en el hueco (tiene más techo que suelo).
const ART_OFFSET_Y: float = 10.0
const BADGE_SIZE: Vector2 = Vector2(58.0, 34.0)
## Cambio mínimo de progreso para redibujar la barra (evita redibujar cada tick).
const PROGRESS_REDRAW_STEP: float = 0.02
## Rebote al producir: duración (s) y fuerza (fracción de aplastamiento máximo).
const BOUNCE_DURATION: float = 0.55
const BOUNCE_STRENGTH: float = 0.22

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
var _art: Sprite2D = null
var _team_layer: Sprite2D = null
var _drawn_progress: float = -1.0
## Posición y escala de reposo del arte (el rebote las anima y siempre vuelve a ellas).
var _art_rest_scale: Vector2 = Vector2.ONE
var _art_rest_position: Vector2 = Vector2.ZERO
var _bounce_tween: Tween = null
## Arte según la raza del dueño (ver _create_visuals).
var _art_texture: Texture2D = null
var _art_team_texture: Texture2D = null


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
	# El indicador de alcance de las torres depende del nivel: hay que redibujarlo.
	queue_redraw()


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


## Solo clientes online: avanza la barra entre snapshots sin disparar ciclos
## (los efectos llegan del servidor; el siguiente snapshot corrige la deriva).
func simulate_visual(delta: float) -> void:
	var interval: float = get_production_interval()
	if interval <= 0.0:
		return
	set_production_timer(fposmod(production_timer + delta, interval))


## Solo clientes online: fija el temporizador replicado por el servidor.
func set_production_timer(seconds: float) -> void:
	var interval_now: float = get_production_interval()
	var wrapped: bool = interval_now > 0.0 and seconds < production_timer - interval_now * 0.5
	production_timer = seconds
	if wrapped:
		_on_visual_cycle()
	var interval: float = get_production_interval()
	if interval > 0.0:
		_refresh_progress(production_timer / interval)


## Segundos entre ciclos de producción. 0 = sin ciclo (la base no produce).
func get_production_interval() -> float:
	return 0.0


## Solo clientes online: el temporizador dio la vuelta = el servidor produjo algo.
## Las subclases con efecto visual de producción lo sobrescriben.
func _on_visual_cycle() -> void:
	pass


## Rebote de "acabo de producir": el edificio se aplasta contra el suelo y se estira
## con un muelle amortiguado (squash & stretch). Se hace con la escala del sprite:
## un shader haría lo mismo, pero necesitaría un material por edificio y no aporta nada
## a un movimiento tan simple.
func play_bounce() -> void:
	if _art == null or GameManager.suppress_effects or not is_inside_tree():
		return
	if _bounce_tween != null and _bounce_tween.is_valid():
		_bounce_tween.kill()
	Sfx.play(&"boing", 0.0 if owner_id == GameManager.local_player_id or GameManager.is_watching() else Sfx.RIVAL_OFFSET_DB)
	_bounce_tween = create_tween()
	_bounce_tween.tween_method(_apply_bounce, 0.0, 1.0, BOUNCE_DURATION)
	_bounce_tween.tween_callback(_apply_bounce.bind(1.0))


## t de 0 a 1: oscilación amortiguada; 0 = reposo, positivo = aplastado, negativo = estirado.
func _apply_bounce(t: float) -> void:
	if _art == null:
		return
	var wave: float = exp(-4.5 * t) * sin(t * TAU * 2.0) if t < 1.0 else 0.0
	var squash: float = BOUNCE_STRENGTH * wave
	_art.scale = _art_rest_scale * Vector2(1.0 + squash * 0.7, 1.0 - squash)
	# El edificio se apoya en su base: se ajusta la posición para que no "flote".
	var half_height: float = _art.texture.get_height() * _art_rest_scale.y * 0.5 if _art.texture != null else 0.0
	var grounded: float = -1.0 if ViewOrientation.is_flipped() else 1.0
	_art.position = _art_rest_position + Vector2(0.0, squash * half_height * grounded)


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
	var race: RaceData = GameManager.get_race(owner_id)
	_art_texture = race.get_structure_texture(data) if race != null else data.texture
	_art_team_texture = race.get_structure_team_texture(data) if race != null else data.team_texture
	if _art_texture != null:
		_create_art()
	elif data.sprite_frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = data.sprite_frames
		if data.sprite_frames.has_animation(data.anim_idle):
			_sprite.play(data.anim_idle)
		add_child(_sprite)
	_label = Label.new()
	if has_art():
		_setup_level_badge()
	else:
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


func has_art() -> bool:
	return _art != null


## Arte estático: el edificio y encima la capa de color de equipo. Con la vista
## girada 180° se contrarrota para que el edificio se vea siempre derecho.
func _create_art() -> void:
	var art_scale: float = body_size.x / ART_REFERENCE_WIDTH * ART_RASTER_SCALE * data.art_scale
	var upright: float = PI if ViewOrientation.is_flipped() else 0.0
	_art = Sprite2D.new()
	_art.texture = _art_texture
	_art.scale = Vector2.ONE * art_scale
	_art.rotation = upright
	_art.position = Vector2(0.0, -ART_OFFSET_Y if upright != 0.0 else ART_OFFSET_Y)
	_art_rest_scale = _art.scale
	_art_rest_position = _art.position
	add_child(_art)
	if _art_team_texture != null:
		_team_layer = Sprite2D.new()
		_team_layer.texture = _art_team_texture
		_team_layer.modulate = MatchTypes.team_color(owner_id)
		_art.add_child(_team_layer)


## Insignia de nivel en la esquina inferior derecha (en pantalla).
func _setup_level_badge() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.07, 0.12, 0.92)
	style.set_corner_radius_all(14)
	style.set_border_width_all(3)
	style.border_color = Color(0.95, 0.76, 0.3)
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	_label.add_theme_stylebox_override("normal", style)
	_label.size = BADGE_SIZE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.7))
	var corner: Vector2 = body_size * 0.5 - BADGE_SIZE + Vector2(6.0, 8.0)
	_label.position = -corner - BADGE_SIZE if ViewOrientation.is_flipped() else corner


func _update_label() -> void:
	if _label == null or data == null:
		return
	if has_art():
		_label.text = "Lv%d" % level
		return
	var short_name: String = tr(data.short_label) if data.short_label != "" else tr(data.display_name)
	_label.text = "%s\nLv%d" % [short_name, level]


func _draw() -> void:
	if data == null:
		return
	var rect: Rect2 = Rect2(-body_size * 0.5, body_size)
	if not has_art():
		if _sprite == null:
			draw_rect(rect, data.color)
		draw_rect(rect, MatchTypes.team_color(owner_id), false, 6.0)
	if get_production_interval() > 0.0:
		var bar: Rect2 = Rect2(rect.position.x + 14.0, rect.end.y - PROGRESS_BAR_HEIGHT - 4.0, rect.size.x - 28.0, PROGRESS_BAR_HEIGHT)
		draw_rect(bar.grow(2.0), Color(0.09, 0.07, 0.12, 0.85))
		var fill: float = bar.size.x * get_progress()
		if fill > 0.5:
			draw_rect(Rect2(bar.position, Vector2(fill, bar.size.y)), Color(0.98, 0.8, 0.3))
			draw_rect(Rect2(bar.position, Vector2(fill, 3.0)), Color(1.0, 1.0, 1.0, 0.35))
