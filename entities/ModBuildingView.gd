class_name ModBuildingView
extends Node2D
## El edificio modificador de un jugador, dibujado en el mundo junto a su castillo (a la
## izquierda del castillo del jugador de abajo; el del rival, en la posición simétrica). Se
## dibuja sobre una marca del color del bando. Tocarlo muestra su nombre y su efecto (se
## cierra a los 4 s). Solo presentación: lee PlayerState.mod_building, igual en local y online.

## Ancho al que se dibuja el edificio (px de mundo) y radio del toque.
const DRAW_SCALE: float = 0.75
const TAP_HALF_SIZE: Vector2 = Vector2(130.0, 135.0)
const INFO_WIDTH: float = 440.0

var player_id: int = MatchTypes.NO_PLAYER

var _shown: StringName = &""
var _sprite: Sprite2D = null
var _info: PanelContainer = null
var _info_label: Label = null
var _info_token: int = 0


func setup(p_player_id: int, world_position: Vector2) -> void:
	player_id = p_player_id
	position = world_position
	name = "ModBuilding_%d" % player_id
	_sprite = Sprite2D.new()
	_sprite.scale = Vector2.ONE * DRAW_SCALE
	_sprite.rotation = PI if ViewOrientation.is_flipped() else 0.0
	_sprite.visible = false
	add_child(_sprite)
	_build_info()
	EventBus.partida_iniciada.connect(func(_mode: int, _seed: int) -> void: _refresh(true))
	_refresh(true)


func _process(_delta: float) -> void:
	_refresh(false)


func get_shown() -> StringName:
	return _shown


func is_info_visible() -> bool:
	return _info.visible


## ¿Cae este punto del mundo sobre el edificio? (para el toque)
func contains_point(world_position: Vector2) -> bool:
	return _shown != &"" and Rect2(global_position - TAP_HALF_SIZE, TAP_HALF_SIZE * 2.0).has_point(world_position)


func toggle_info() -> void:
	if _shown == &"":
		return
	if _info.visible:
		_hide_info()
		return
	_info_label.text = "%s\n%s" % [ModBuildings.display_name(_shown), ModBuildings.description(_shown)]
	_info.reset_size()
	# Sobre el edificio; con la vista girada el cuadro también se gira para leerse derecho.
	var above: float = -TAP_HALF_SIZE.y - _info.size.y - 6.0
	var flipped: bool = ViewOrientation.is_flipped()
	_info.pivot_offset = _info.size * 0.5
	_info.rotation = PI if flipped else 0.0
	_info.position = Vector2(-_info.size.x * 0.5, -above - _info.size.y if flipped else above)
	_info.visible = true
	_info_token += 1
	get_tree().create_timer(4.0).timeout.connect(_hide_info_if_current.bind(_info_token))


func _refresh(force: bool) -> void:
	var player_state: PlayerState = GameManager.get_player_state(player_id)
	var current: StringName = player_state.mod_building if player_state != null else &""
	if not force and current == _shown:
		return
	_shown = current
	_hide_info()
	_sprite.texture = ModBuildings.icon(current) if current != &"" else null
	_sprite.visible = current != &""
	queue_redraw()


## Marca del bando bajo el edificio: una elipse en el suelo con el color del jugador.
func _draw() -> void:
	if _shown == &"":
		return
	var color: Color = MatchTypes.team_color(player_id)
	draw_set_transform(Vector2(0.0, 92.0), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 112.0, Color(color, 0.32))
	draw_arc(Vector2.ZERO, 112.0, 0.0, TAU, 48, Color(color, 0.95), 7.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _build_info() -> void:
	_info = PanelContainer.new()
	_info.visible = false
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.z_index = 5
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.09, 0.07, 0.95)
	style.set_corner_radius_all(18)
	style.set_border_width_all(4)
	style.border_color = MatchTypes.team_color(player_id)
	style.set_content_margin_all(14.0)
	_info.add_theme_stylebox_override("panel", style)
	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 30)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.custom_minimum_size = Vector2(INFO_WIDTH, 0.0)
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_child(_info_label)
	add_child(_info)


func _hide_info() -> void:
	_info.visible = false


func _hide_info_if_current(token: int) -> void:
	if token == _info_token:
		_hide_info()
