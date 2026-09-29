class_name Castle
extends Node2D
## Vista de un castillo. La vida real vive en PlayerState.castle_hp y la
## modifica LaneManager; este nodo solo la muestra (cuerpo, barra y número).
## El origen del nodo es el centro del castillo.

const HP_BAR_HEIGHT: float = 14.0

@export var owner_id: int = MatchTypes.PLAYER_BOTTOM
@export var body_size: Vector2 = Vector2(360.0, 120.0)

var _hp: float = 1.0
var _max_hp: float = 1.0
var _label: Label = null


func _ready() -> void:
	add_to_group(&"castle")
	_label = Label.new()
	_label.position = -body_size * 0.5
	_label.size = body_size
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 40)
	_label.add_theme_constant_override("outline_size", 8)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_label)
	EventBus.castillo_danado.connect(_on_castillo_danado)
	EventBus.partida_iniciada.connect(_on_partida_iniciada)
	_refresh_from_state()


func _refresh_from_state() -> void:
	ViewOrientation.orient(_label)
	var player_state: PlayerState = GameManager.get_player_state(owner_id)
	if player_state == null:
		_show(1.0, 1.0)
		return
	_show(player_state.castle_hp, player_state.castle_max_hp)


func _show(hp: float, max_hp: float) -> void:
	_hp = hp
	_max_hp = maxf(max_hp, 1.0)
	_label.text = "%d" % ceili(_hp)
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(-body_size * 0.5, body_size)
	var color: Color = MatchTypes.team_color(owner_id)
	draw_rect(rect, color.darkened(0.25) if _hp > 0.0 else Color(0.2, 0.2, 0.2))
	draw_rect(rect, color.lightened(0.3), false, 4.0)
	var bar: Rect2 = Rect2(rect.position.x, rect.end.y - HP_BAR_HEIGHT, rect.size.x, HP_BAR_HEIGHT)
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.7))
	var ratio: float = clampf(_hp / _max_hp, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), Color.RED.lerp(Color.LIME_GREEN, ratio))


func _on_castillo_danado(player_id: int, vida_actual: float, vida_maxima: float) -> void:
	if player_id == owner_id:
		_show(vida_actual, vida_maxima)


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	_refresh_from_state()
