class_name Castle
extends Node2D
## Vista de un castillo. La vida real vive en PlayerState.castle_hp y la
## modifica LaneManager; este nodo solo la muestra (cuerpo, barra y número).
## El origen del nodo es el centro del castillo.

const ART: Texture2D = preload("res://assets/structures/castle.svg")
const ART_TEAM: Texture2D = preload("res://assets/structures/castle_team.svg")
## Los SVG se rasterizan a 2x.
const ART_SCALE: float = 0.5
## Placa de vida bajo el castillo (a caballo entre el muro y el suelo).
const PLAQUE_SIZE: Vector2 = Vector2(200.0, 44.0)
## Distancia del centro del castillo al borde de la placa más cercano.
const PLAQUE_TOP: float = 34.0
const BAR_HEIGHT: float = 8.0
## El arte sube un poco para dejar sitio a la placa entre castillo y plots.
const ART_LIFT: float = 8.0
## Derrumbe: sacudidas, amplitud (px), cuánto se hunde y en cuánto se aplasta.
const COLLAPSE_SHAKES: int = 10
const COLLAPSE_SHAKE: float = 14.0
const COLLAPSE_SINK: float = 22.0

@export var owner_id: int = MatchTypes.PLAYER_BOTTOM
@export var body_size: Vector2 = Vector2(360.0, 120.0)

var _hp: float = 1.0
var _max_hp: float = 1.0
var _label: Label = null
var _art: Sprite2D = null
var _team_layer: Sprite2D = null
var _plaque_style: StyleBoxFlat = null
var _dirty: bool = false
## El derrumbe ya se ha reproducido en esta partida.
var _collapsed: bool = false
var _collapse_tween: Tween = null


func _ready() -> void:
	add_to_group(&"castle")
	_create_art()
	_plaque_style = StyleBoxFlat.new()
	_plaque_style.bg_color = Color(0.09, 0.07, 0.12, 0.92)
	_plaque_style.set_corner_radius_all(16)
	_plaque_style.set_border_width_all(4)
	_plaque_style.border_color = Color(0.95, 0.76, 0.3)
	_label = Label.new()
	_label.size = Vector2(PLAQUE_SIZE.x, 31.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 27)
	_label.add_theme_constant_override("outline_size", 5)
	_label.add_theme_color_override("font_outline_color", Color(0.09, 0.07, 0.12))
	add_child(_label)
	EventBus.castillo_danado.connect(_on_castillo_danado)
	EventBus.partida_iniciada.connect(_on_partida_iniciada)
	_refresh_from_state()


## Fortaleza al estilo Warcraft 3 con la capa de estandartes teñida con el
## color del bando. Con la vista girada se contrarrota para verse derecha.
func _create_art() -> void:
	_art = Sprite2D.new()
	_art.texture = ART
	_art.scale = Vector2.ONE * ART_SCALE
	# La placa de vida (dibujada por el propio nodo) queda por encima del arte.
	_art.show_behind_parent = true
	add_child(_art)
	_team_layer = Sprite2D.new()
	_team_layer.texture = ART_TEAM
	_team_layer.modulate = MatchTypes.team_color(owner_id)
	_art.add_child(_team_layer)


## La placa cae siempre por debajo del castillo en pantalla.
func _plaque_rect() -> Rect2:
	var y: float = -PLAQUE_TOP - PLAQUE_SIZE.y if ViewOrientation.is_flipped() else PLAQUE_TOP
	return Rect2(Vector2(-PLAQUE_SIZE.x * 0.5, y), PLAQUE_SIZE)


## La orientación de la vista se conoce al empezar la partida, no en _ready.
func _apply_orientation() -> void:
	var flipped: bool = ViewOrientation.is_flipped()
	_art.rotation = PI if flipped else 0.0
	_art.position = Vector2(0.0, ART_LIFT if flipped else -ART_LIFT)
	_label.position = _plaque_rect().position + Vector2(0.0, 12.0 if flipped else 1.0)
	ViewOrientation.orient(_label)


func _refresh_from_state() -> void:
	_apply_orientation()
	var player_state: PlayerState = GameManager.get_player_state(owner_id)
	if player_state == null:
		_show(1.0, 1.0)
		return
	_show(player_state.castle_hp, player_state.castle_max_hp)


func _show(hp: float, max_hp: float) -> void:
	_hp = hp
	_max_hp = maxf(max_hp, 1.0)
	_label.text = "%d" % ceili(_hp)
	if _art != null:
		# Castillo caído: piedra apagada y sin estandartes.
		_art.modulate = Color.WHITE if _hp > 0.0 else Color(0.38, 0.38, 0.4)
		_team_layer.visible = _hp > 0.0
	queue_redraw()


func _draw() -> void:
	var plaque: Rect2 = _plaque_rect()
	draw_style_box(_plaque_style, plaque)
	var flipped: bool = ViewOrientation.is_flipped()
	var bar_y: float = plaque.position.y + 6.0 if flipped else plaque.end.y - BAR_HEIGHT - 6.0
	var bar: Rect2 = Rect2(plaque.position.x + 14.0, bar_y, plaque.size.x - 28.0, BAR_HEIGHT)
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.6))
	var ratio: float = clampf(_hp / _max_hp, 0.0, 1.0)
	var fill: Color = Color(0.95, 0.25, 0.2).lerp(Color(0.45, 0.85, 0.3), ratio)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), fill)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, 3.0)), Color(1.0, 1.0, 1.0, 0.3))


func _on_castillo_danado(player_id: int, vida_actual: float, vida_maxima: float) -> void:
	if player_id == owner_id:
		if vida_actual <= 0.0:
			_play_collapse()
		# Se guarda el último valor y se dibuja una vez por fotograma.
		_hp = vida_actual
		_max_hp = maxf(vida_maxima, 1.0)
		_dirty = true


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_show(_hp, _max_hp)


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	_reset_collapse()
	_apply_race_art()
	_refresh_from_state()


## Derrumbe: el castillo se sacude, se hunde un poco y suelta polvo y escombros. Con la
## cámara lenta de Main.gd dura unos segundos en pantalla.
func _play_collapse() -> void:
	if _collapsed or GameManager.suppress_effects or not is_inside_tree():
		return
	_collapsed = true
	Sfx.play(&"thunder", 0.0)
	var flipped: bool = ViewOrientation.is_flipped()
	var rest: Vector2 = _art.position
	var sink: float = -COLLAPSE_SINK if flipped else COLLAPSE_SINK
	_collapse_tween = create_tween()
	for step: int in COLLAPSE_SHAKES:
		var amount: float = COLLAPSE_SHAKE * (1.0 - float(step) / float(COLLAPSE_SHAKES))
		_collapse_tween.tween_property(_art, "position", rest + Vector2(amount if step % 2 == 0 else -amount, 0.0), 0.06)
	_collapse_tween.tween_property(_art, "position", rest + Vector2(0.0, sink), 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_collapse_tween.parallel().tween_property(_art, "scale", Vector2(ART_SCALE * 1.05, ART_SCALE * 0.84), 0.35)
	var up: Vector2 = Vector2.DOWN if flipped else Vector2.UP
	add_child(_make_debris(up))
	add_child(_make_dust(up))


func _reset_collapse() -> void:
	_collapsed = false
	if _collapse_tween != null and _collapse_tween.is_valid():
		_collapse_tween.kill()
	for child: Node in get_children():
		if child is CPUParticles2D:
			child.queue_free()
	if _art != null:
		_art.scale = Vector2.ONE * ART_SCALE


func _make_debris(up: Vector2) -> CPUParticles2D:
	var debris: CPUParticles2D = CPUParticles2D.new()
	debris.one_shot = true
	debris.explosiveness = 0.95
	debris.amount = 46
	debris.lifetime = 1.6
	debris.direction = up
	debris.spread = 65.0
	debris.initial_velocity_min = 180.0
	debris.initial_velocity_max = 420.0
	debris.gravity = -up * 620.0
	debris.scale_amount_min = 5.0
	debris.scale_amount_max = 13.0
	debris.color = Color(0.62, 0.58, 0.52)
	debris.z_index = 6
	debris.position = Vector2(0.0, -20.0 if up == Vector2.UP else 20.0)
	debris.emitting = true
	return debris


func _make_dust(up: Vector2) -> CPUParticles2D:
	var dust: CPUParticles2D = CPUParticles2D.new()
	dust.one_shot = true
	dust.explosiveness = 0.6
	dust.amount = 28
	dust.lifetime = 2.4
	dust.direction = up
	dust.spread = 80.0
	dust.initial_velocity_min = 40.0
	dust.initial_velocity_max = 140.0
	dust.gravity = up * 30.0
	dust.scale_amount_min = 26.0
	dust.scale_amount_max = 54.0
	dust.color = Color(0.82, 0.78, 0.7, 0.55)
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.65))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	dust.color_ramp = fade
	dust.z_index = 6
	dust.emitting = true
	return dust


## El castillo usa el arte de la raza del dueño (data/races) si lo define.
func _apply_race_art() -> void:
	var race: RaceData = GameManager.get_race(owner_id)
	if race == null or _art == null:
		return
	_art.texture = race.castle_texture if race.castle_texture != null else ART
	_team_layer.texture = race.castle_team_texture if race.castle_team_texture != null else ART_TEAM
