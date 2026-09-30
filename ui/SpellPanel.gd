class_name SpellPanel
extends Control
## Habilidades de castillo: tres botones a la derecha de la pantalla, encima de la
## barra de la tienda. Se arrastran hasta tu mitad del carril y, al soltar, se envía un
## CastSpellCommand (la autoridad valida punto y tiempo de espera). El tiempo de
## espera que se muestra sale del estado de la partida, igual en local y online.

signal drag_started
signal drag_finished

const BOTTOM_BAR_HEIGHT: float = 420.0
const MARGIN: float = 24.0

var local_input: LocalInputController = null

var _buttons: Array[SpellButton] = []
var _column: VBoxContainer = null
var _drag_icon: TextureRect = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 14)
	_column.anchor_left = 1.0
	_column.anchor_right = 1.0
	_column.anchor_top = 1.0
	_column.anchor_bottom = 1.0
	_column.offset_right = -MARGIN
	_column.offset_bottom = -(BOTTOM_BAR_HEIGHT + MARGIN)
	_column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_column)
	var spells: Array[SpellData] = GameManager.database.spells if GameManager.database != null else []
	for spell: SpellData in spells:
		var button: SpellButton = SpellButton.new()
		_column.add_child(button)
		button.setup(spell)
		button.drag_started.connect(_on_drag_started)
		button.drag_moved.connect(_on_drag_moved)
		button.drag_released.connect(_on_drag_released)
		button.tapped.connect(_on_tapped)
		_buttons.append(button)
	_drag_icon = TextureRect.new()
	_drag_icon.top_level = true
	_drag_icon.visible = false
	_drag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_icon.custom_minimum_size = Vector2(110.0, 110.0)
	_drag_icon.size = Vector2(110.0, 110.0)
	_drag_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_drag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_drag_icon)
	EventBus.partida_iniciada.connect(func(_mode: int, _seed: int) -> void: _refresh_visibility())
	_refresh_visibility()


func connect_input(input: LocalInputController) -> void:
	local_input = input


func _process(_delta: float) -> void:
	var state: PlayerState = GameManager.get_player_state(GameManager.local_player_id)
	if state == null or GameManager.match_state == null:
		return
	var now: float = GameManager.match_state.match_time
	for button: SpellButton in _buttons:
		button.set_cooldown(maxf(0.0, state.get_spell_ready_at(button.spell.id) - now), button.spell.cooldown)


func _refresh_visibility() -> void:
	_column.visible = not GameManager.is_watching()


func _on_tapped(button: SpellButton) -> void:
	# Un toque suelto no lanza nada: recuerda cómo se usa.
	var hud: HUD = get_parent() as HUD
	if hud != null and button.is_ready_to_cast():
		hud.show_toast(tr("Arrastra el hechizo a tu mitad del carril"))


func _on_drag_started(button: SpellButton, screen_position: Vector2) -> void:
	if local_input == null:
		return
	_drag_icon.texture = button.spell.icon
	_drag_icon.visible = true
	_move_icon(screen_position)
	local_input.begin_spell_drag(button.spell)
	drag_started.emit()


func _on_drag_moved(_button: SpellButton, screen_position: Vector2) -> void:
	if local_input == null:
		return
	_move_icon(screen_position)
	local_input.update_spell_drag(screen_position)


func _on_drag_released(button: SpellButton, screen_position: Vector2) -> void:
	if local_input == null:
		return
	_drag_icon.visible = false
	# Soltarlo sobre la barra de la tienda cancela el lanzamiento.
	var cancelled: bool = screen_position.y > get_viewport_rect().size.y - BOTTOM_BAR_HEIGHT
	local_input.end_spell_drag(button.spell, screen_position, cancelled)
	drag_finished.emit()


func _move_icon(screen_position: Vector2) -> void:
	_drag_icon.global_position = screen_position - _drag_icon.size * 0.5 - Vector2(0.0, 90.0)
