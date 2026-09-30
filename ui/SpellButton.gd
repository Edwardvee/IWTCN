class_name SpellButton
extends PanelContainer
## Botón de una habilidad de castillo: icono, tiempo de espera y arrastre hacia el
## carril (mismo gesto que las cartas). Solo presentación: SpellPanel decide qué hacer.

signal drag_started(button: SpellButton, screen_position: Vector2)
signal drag_moved(button: SpellButton, screen_position: Vector2)
signal drag_released(button: SpellButton, screen_position: Vector2)
signal tapped(button: SpellButton)

const DRAG_THRESHOLD: float = 14.0
const BUTTON_SIZE: float = 128.0

var spell: SpellData = null

var _style: StyleBoxFlat = null
var _icon: TextureRect = null
var _shade: ColorRect = null
var _label: Label = null
var _pressed: bool = false
var _dragging: bool = false
var _press_position: Vector2 = Vector2.ZERO
var _ready_state: bool = true


func setup(p_spell: SpellData) -> void:
	spell = p_spell
	custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	pivot_offset = Vector2(BUTTON_SIZE, BUTTON_SIZE) * 0.5
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.13, 0.09, 0.07, 0.94)
	_style.set_corner_radius_all(24)
	_style.set_border_width_all(6)
	_style.border_color = spell.color
	_style.set_content_margin_all(8.0)
	_style.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	_style.shadow_size = 8
	_style.shadow_offset = Vector2(0.0, 5.0)
	add_theme_stylebox_override("panel", _style)
	_icon = TextureRect.new()
	_icon.texture = spell.icon
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_icon)
	# Capa oscura que baja mientras se recarga y segundos restantes encima.
	_shade = ColorRect.new()
	_shade.color = Color(0.0, 0.0, 0.0, 0.62)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.top_level = false
	_shade.visible = false
	add_child(_shade)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 58)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color(0.09, 0.07, 0.12))
	_label.add_theme_constant_override("outline_size", 14)
	_label.visible = false
	add_child(_label)


func is_ready_to_cast() -> bool:
	return _ready_state


## left = segundos que faltan; total = espera completa del hechizo.
func set_cooldown(left: float, total: float) -> void:
	_ready_state = left <= 0.0
	_shade.visible = not _ready_state
	_label.visible = not _ready_state
	if not _ready_state:
		_label.text = str(ceili(left))
		# Un PanelContainer coloca a sus hijos a pantalla completa: la capa se encoge desde arriba.
		var covered: float = clampf(left / maxf(total, 0.01), 0.0, 1.0)
		_shade.size_flags_vertical = Control.SIZE_SHRINK_END
		_shade.custom_minimum_size = Vector2(0.0, (BUTTON_SIZE - 28.0) * covered)
	modulate = Color.WHITE if _ready_state else Color(1.0, 1.0, 1.0, 0.85)


func _gui_input(event: InputEvent) -> void:
	if spell == null:
		return
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			_pressed = true
			_press_position = button.global_position
			scale = Vector2(0.95, 0.95)
		else:
			if _dragging:
				drag_released.emit(self, button.global_position)
			elif _pressed:
				tapped.emit(self)
			_pressed = false
			_dragging = false
			scale = Vector2.ONE
		accept_event()
	elif event is InputEventMouseMotion and _pressed:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if not _dragging and motion.global_position.distance_to(_press_position) > DRAG_THRESHOLD and _ready_state:
			_dragging = true
			drag_started.emit(self, motion.global_position)
		if _dragging:
			drag_moved.emit(self, motion.global_position)
		accept_event()
