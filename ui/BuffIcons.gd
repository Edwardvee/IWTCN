class_name BuffIcons
extends Control
## Mejoras activas del jugador local como iconitos con borde violeta, en columna bajo el
## botón del menú. Si compras la misma mejora varias veces, el icono lleva "x2", "x3"…
## Solo presentación: lee PlayerState.buffs, así funciona igual en local y online.

const COLUMN_POSITION: Vector2 = Vector2(24.0, 252.0)
const ICON_SIZE: float = 76.0
const BORDER_COLOR: Color = Color("a768ff")

var _column: VBoxContainer = null
## Cuadro con lo que da una mejora (al pulsar su icono) y qué icono lo abrió.
var _info: PanelContainer = null
var _info_label: Label = null
var _info_buff: StringName = &""
var _info_token: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_column = VBoxContainer.new()
	_column.position = COLUMN_POSITION
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", 10)
	add_child(_column)
	_build_info()
	EventBus.buff_aplicado.connect(func(player_id: int, _buff: BuffData) -> void:
		if player_id == GameManager.local_player_id:
			_refresh())
	EventBus.partida_iniciada.connect(func(_mode: int, _seed: int) -> void: _refresh())
	_refresh()


## Cuántas copias hay de cada mejora, en el orden en que se compraron.
static func count_buffs(buff_ids: Array[StringName]) -> Dictionary[StringName, int]:
	var counts: Dictionary[StringName, int] = {}
	for buff_id: StringName in buff_ids:
		counts[buff_id] = counts.get(buff_id, 0) + 1
	return counts


## Texto de lo que dan `count` copias de una mejora: nombre y efecto total.
static func describe(buff: BuffData, count: int) -> String:
	var header: String = TranslationServer.translate(buff.display_name) if count <= 1 else "%s  x%d" % [TranslationServer.translate(buff.display_name), count]
	var total: float = buff.value * count
	var percent: int = roundi(absf(total) * 100.0)
	var body: String = TranslationServer.translate(buff.display_name)
	match buff.stat:
		BuffData.Stat.MOVE_SPEED:
			body = TranslationServer.translate("Tus unidades se mueven un %d %% más rápido") % percent
		BuffData.Stat.MAX_HP:
			body = TranslationServer.translate("Tus unidades tienen un %d %% más de vida") % percent
		BuffData.Stat.DAMAGE:
			body = TranslationServer.translate("Tus unidades hacen un %d %% más de daño") % percent
		BuffData.Stat.DAMAGE_MITIGATION:
			body = TranslationServer.translate("Tus unidades reciben un %d %% menos de daño") % mini(percent, 90)
		BuffData.Stat.PRODUCTION_INTERVAL:
			body = TranslationServer.translate("Tus cuarteles e iglesias producen %.1f s más rápido") % absf(total)
		BuffData.Stat.UNIT_CAP:
			body = TranslationServer.translate("Tu límite de tropas sube en %d") % roundi(total)
		BuffData.Stat.TOWER_FIRE_RATE:
			body = TranslationServer.translate("Tus torres disparan un %d %% más rápido") % percent
	return "%s
%s" % [header, body]


static func label_for_count(count: int) -> String:
	return "x%d" % count if count > 1 else ""


## Icono de la mejora: el de la carta que la vende.
static func icon_for(buff_id: StringName) -> Texture2D:
	if GameManager.database == null:
		return null
	for card: CardData in GameManager.database.cards:
		if card.buff != null and card.buff.id == buff_id:
			return card.icon
	return null


func get_icon_count() -> int:
	return _column.get_child_count()


func _build_info() -> void:
	_info = PanelContainer.new()
	_info.visible = false
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.09, 0.07, 0.95)
	style.set_corner_radius_all(18)
	style.set_border_width_all(4)
	style.border_color = BORDER_COLOR
	style.set_content_margin_all(14.0)
	_info.add_theme_stylebox_override("panel", style)
	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 30)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.custom_minimum_size = Vector2(520.0, 0.0)
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_child(_info_label)
	add_child(_info)


## Pulsar un icono muestra (o esconde) lo que da esa mejora; se cierra solo a los 4 s.
func show_info(buff_id: StringName, frame: Control) -> void:
	if _info.visible and _info_buff == buff_id:
		_hide_info()
		return
	var buff: BuffData = GameManager.database.get_buff(buff_id)
	var player_state: PlayerState = GameManager.get_player_state(GameManager.local_player_id)
	if buff == null or player_state == null:
		return
	_info_buff = buff_id
	_info_label.text = describe(buff, player_state.buffs.count(buff_id))
	_info.reset_size()
	_info.position = frame.get_global_rect().position - get_global_rect().position + Vector2(ICON_SIZE + 14.0, 0.0)
	_info.visible = true
	_info_token += 1
	get_tree().create_timer(4.0).timeout.connect(_hide_info_if_current.bind(_info_token))


func is_info_visible() -> bool:
	return _info.visible


func _hide_info() -> void:
	_info.visible = false
	_info_buff = &""


func _hide_info_if_current(token: int) -> void:
	if token == _info_token:
		_hide_info()


func _on_icon_input(event: InputEvent, buff_id: StringName, frame: Control) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		show_info(buff_id, frame)
		frame.accept_event()


func _refresh() -> void:
	_hide_info()
	for child: Node in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	var player_state: PlayerState = GameManager.get_player_state(GameManager.local_player_id)
	if player_state == null or GameManager.is_watching():
		return
	var counts: Dictionary[StringName, int] = count_buffs(player_state.buffs)
	for buff_id: StringName in counts:
		_column.add_child(_make_icon(buff_id, counts[buff_id]))


func _make_icon(buff_id: StringName, count: int) -> Control:
	var frame: PanelContainer = PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.gui_input.connect(_on_icon_input.bind(buff_id, frame))
	frame.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.09, 0.07, 0.92)
	style.set_corner_radius_all(16)
	style.set_border_width_all(5)
	style.border_color = BORDER_COLOR
	style.set_content_margin_all(5.0)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0.0, 3.0)
	frame.add_theme_stylebox_override("panel", style)
	var picture: TextureRect = TextureRect.new()
	picture.texture = icon_for(buff_id)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(picture)
	var badge_text: String = label_for_count(count)
	if badge_text != "":
		var badge: Label = Label.new()
		badge.text = badge_text
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		badge.add_theme_font_size_override("font_size", 34)
		badge.add_theme_color_override("font_color", Color(1.0, 0.93, 0.7))
		badge.add_theme_color_override("font_outline_color", Color(0.09, 0.07, 0.12))
		badge.add_theme_constant_override("outline_size", 10)
		frame.add_child(badge)
	return frame
