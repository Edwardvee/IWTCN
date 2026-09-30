class_name EmotePanel
extends Control
## Botón de emotes (como en Clash Royale) y globos con los emotes de ambos jugadores.
##
## Solo presentación: el botón abre un selector con los emotes de Emotes.IDS, la
## elección se envía como EmoteCommand (la autoridad valida el tiempo de espera) y
## los globos se dibujan al recibir EventBus.emote_mostrado, igual en local,
## online y repeticiones. Tu emote sale junto al botón; el del rival, arriba a la derecha.

const BOTTOM_BAR_HEIGHT: float = 420.0
const MARGIN: float = 24.0
const TOGGLE_SIZE: float = 124.0
const PICK_SIZE: float = 136.0
const BUBBLE_SIZE: float = 184.0
const RIVAL_BUBBLE_TOP: float = 340.0

var _toggle: Button = null
var _cooldown_label: Label = null
var _picker: PanelContainer = null
var _pick_buttons: Array[Button] = []
var _bubbles: Dictionary[bool, PanelContainer] = {}
var _bubble_tweens: Dictionary[bool, Tween] = {}
## Segundos que faltan para poder enviar otro emote.
var _cooldown_left: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_toggle()
	_build_picker()
	_bubbles[true] = _build_bubble(true)
	_bubbles[false] = _build_bubble(false)
	EventBus.emote_mostrado.connect(_on_emote_mostrado)
	EventBus.partida_iniciada.connect(_on_partida_iniciada)
	EventBus.partida_terminada.connect(_on_partida_terminada)
	_refresh_visibility()


func _process(delta: float) -> void:
	if _cooldown_left <= 0.0:
		return
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	_refresh_cooldown()


## Segundos de espera que quedan (para tests y otros elementos de interfaz).
func get_cooldown_left() -> float:
	return _cooldown_left


func _build_toggle() -> void:
	_toggle = Button.new()
	_toggle.theme_type_variation = &"WoodButton"
	_toggle.icon = Emotes.get_texture(Emotes.IDS[0])
	_toggle.expand_icon = true
	_toggle.add_theme_constant_override("icon_max_width", 88)
	_toggle.custom_minimum_size = Vector2(TOGGLE_SIZE, TOGGLE_SIZE)
	_place(_toggle, MARGIN, BOTTOM_BAR_HEIGHT + MARGIN, TOGGLE_SIZE, TOGGLE_SIZE)
	_toggle.pressed.connect(_on_toggle_pressed)
	add_child(_toggle)
	_cooldown_label = Label.new()
	_cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cooldown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cooldown_label.add_theme_font_size_override("font_size", 64)
	_cooldown_label.add_theme_color_override("font_color", Color.WHITE)
	_cooldown_label.add_theme_color_override("font_outline_color", Color(0.09, 0.07, 0.12))
	_cooldown_label.add_theme_constant_override("outline_size", 14)
	_cooldown_label.visible = false
	_toggle.add_child(_cooldown_label)


func _build_picker() -> void:
	_picker = PanelContainer.new()
	_picker.visible = false
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.09, 0.07, 0.94)
	style.set_corner_radius_all(26)
	style.set_border_width_all(4)
	style.border_color = Color(0.95, 0.76, 0.3)
	style.set_content_margin_all(12.0)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 5.0)
	_picker.add_theme_stylebox_override("panel", style)
	_picker.anchor_top = 1.0
	_picker.anchor_bottom = 1.0
	_picker.offset_left = MARGIN
	_picker.offset_bottom = -(BOTTOM_BAR_HEIGHT + MARGIN + TOGGLE_SIZE + 14.0)
	_picker.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_picker.add_child(row)
	for emote_id: StringName in Emotes.IDS:
		var button: Button = Button.new()
		button.theme_type_variation = &"WoodButton"
		button.icon = Emotes.get_texture(emote_id)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 100)
		button.custom_minimum_size = Vector2(PICK_SIZE, PICK_SIZE)
		button.pressed.connect(_on_emote_picked.bind(emote_id))
		row.add_child(button)
		_pick_buttons.append(button)
	add_child(_picker)


## own = globo del jugador local (junto al botón); si no, el del rival (arriba).
func _build_bubble(own: bool) -> PanelContainer:
	var bubble: PanelContainer = PanelContainer.new()
	bubble.visible = false
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.custom_minimum_size = Vector2(BUBBLE_SIZE, BUBBLE_SIZE)
	if own:
		_place(bubble, MARGIN * 2.0 + TOGGLE_SIZE, BOTTOM_BAR_HEIGHT + MARGIN, BUBBLE_SIZE, BUBBLE_SIZE)
	else:
		bubble.anchor_left = 1.0
		bubble.anchor_right = 1.0
		bubble.offset_left = -(MARGIN + BUBBLE_SIZE)
		bubble.offset_right = -MARGIN
		bubble.offset_top = RIVAL_BUBBLE_TOP
		bubble.offset_bottom = RIVAL_BUBBLE_TOP + BUBBLE_SIZE
	var picture: TextureRect = TextureRect.new()
	picture.name = "Picture"
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bubble.add_child(picture)
	add_child(bubble)
	return bubble


## Coloca un control pegado abajo a la izquierda: `left` desde el borde izquierdo,
## `bottom` desde el borde inferior.
func _place(control: Control, left: float, bottom: float, width: float, height: float) -> void:
	control.anchor_top = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = left
	control.offset_right = left + width
	control.offset_top = -(bottom + height)
	control.offset_bottom = -bottom


func _refresh_visibility() -> void:
	var can_send: bool = not GameManager.is_watching()
	_toggle.visible = can_send
	if not can_send:
		_picker.visible = false


func _refresh_cooldown() -> void:
	var waiting: bool = _cooldown_left > 0.0
	_cooldown_label.visible = waiting
	_cooldown_label.text = str(ceili(_cooldown_left))
	_toggle.modulate = Color(1.0, 1.0, 1.0, 0.55) if waiting else Color.WHITE
	for button: Button in _pick_buttons:
		button.disabled = waiting
	if waiting:
		_picker.visible = false


func _on_toggle_pressed() -> void:
	if _cooldown_left > 0.0:
		return
	_picker.visible = not _picker.visible


func _on_emote_picked(emote_id: StringName) -> void:
	_picker.visible = false
	if _cooldown_left > 0.0:
		return
	if GameManager.submit_command(EmoteCommand.new(GameManager.local_player_id, emote_id)):
		_cooldown_left = Emotes.COOLDOWN
		_refresh_cooldown()


func _on_emote_mostrado(player_id: int, emote_id: StringName) -> void:
	var own: bool = player_id == GameManager.local_player_id
	# Aunque el emote propio llegue de la autoridad (online), el tiempo de espera cuenta.
	if own and not GameManager.is_watching() and _cooldown_left <= 0.0:
		_cooldown_left = Emotes.COOLDOWN
		_refresh_cooldown()
	if GameManager.suppress_effects:
		return
	var bubble: PanelContainer = _bubbles[own]
	(bubble.get_node("Picture") as TextureRect).texture = Emotes.get_texture(emote_id)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.99, 0.96, 0.88, 0.96)
	style.set_corner_radius_all(44)
	style.set_border_width_all(7)
	style.border_color = MatchTypes.team_color(player_id)
	style.set_content_margin_all(12.0)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 5.0)
	bubble.add_theme_stylebox_override("panel", style)
	bubble.visible = true
	bubble.modulate = Color.WHITE
	bubble.pivot_offset = Vector2(BUBBLE_SIZE, BUBBLE_SIZE) * 0.5 if not own else Vector2(0.0, BUBBLE_SIZE)
	bubble.scale = Vector2(0.2, 0.2)
	var previous: Tween = _bubble_tweens.get(own, null)
	if previous != null and previous.is_valid():
		previous.kill()
	var tween: Tween = create_tween()
	_bubble_tweens[own] = tween
	tween.tween_property(bubble, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(Emotes.DISPLAY_TIME)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.3)
	tween.tween_callback(bubble.hide)


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	_cooldown_left = 0.0
	_refresh_cooldown()
	for bubble: PanelContainer in _bubbles.values():
		bubble.hide()
	_refresh_visibility()


func _on_partida_terminada(_ganador_player_id: int) -> void:
	_picker.visible = false
