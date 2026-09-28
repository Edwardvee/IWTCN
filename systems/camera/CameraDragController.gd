class_name CameraDragController
extends Camera2D
## Cámara del mundo con desplazamiento vertical (arrastre táctil/ratón y rueda).
##
## Solo mueve la vista: no toca estado de gameplay. Usa _unhandled_input para
## que la UI (Controls con mouse_filter STOP) tenga prioridad sobre el arrastre.
## En PC el ratón genera eventos táctiles (input_devices/pointing/emulate_touch_from_mouse).

@export var world_width: float = 1080.0
@export var world_height: float = 3200.0
## Espacio extra por encima del mundo para que la barra superior no tape el grid enemigo.
@export var top_padding: float = 140.0
## Espacio extra por debajo del mundo para que la barra inferior no tape el grid propio.
@export var bottom_padding: float = 440.0
@export var wheel_step: float = 160.0
@export var start_at_bottom: bool = true
## Se desactiva mientras se arrastra una carta para no mover la cámara.
var input_enabled: bool = true


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	position.x = world_width * 0.5
	position.y = _get_max_center_y() if start_at_bottom else _get_min_center_y()
	_clamp_position()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index != 0:
			return
		scroll_by(-drag.relative.y / zoom.y)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if not mouse_button.pressed:
			return
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_by(-wheel_step)
			get_viewport().set_input_as_handled()
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_by(wheel_step)
			get_viewport().set_input_as_handled()


func scroll_by(delta_y: float) -> void:
	position.y += delta_y
	_clamp_position()


func _clamp_position() -> void:
	position.x = world_width * 0.5
	position.y = clampf(position.y, _get_min_center_y(), _get_max_center_y())


func _get_half_visible_height() -> float:
	return get_viewport_rect().size.y / zoom.y * 0.5


func _get_min_center_y() -> float:
	var min_y: float = -top_padding + _get_half_visible_height()
	var max_y: float = world_height + bottom_padding - _get_half_visible_height()
	# Si la pantalla es más alta que el mundo, se centra.
	return minf(min_y, (min_y + max_y) * 0.5)


func _get_max_center_y() -> float:
	var min_y: float = -top_padding + _get_half_visible_height()
	var max_y: float = world_height + bottom_padding - _get_half_visible_height()
	return maxf(max_y, (min_y + max_y) * 0.5)


func _on_viewport_size_changed() -> void:
	_clamp_position()
