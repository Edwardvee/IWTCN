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

@export var owner_id: int = MatchTypes.PLAYER_BOTTOM
@export var body_size: Vector2 = Vector2(360.0, 120.0)

var _hp: float = 1.0
var _max_hp: float = 1.0
var _label: Label = null
var _art: Sprite2D = null
var _team_layer: Sprite2D = null
var _plaque_style: StyleBoxFlat = null
var _dirty: bool = false


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
		# Se guarda el último valor y se dibuja una vez por fotograma.
		_hp = vida_actual
		_max_hp = maxf(vida_maxima, 1.0)
		_dirty = true


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_show(_hp, _max_hp)


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	_refresh_from_state()
