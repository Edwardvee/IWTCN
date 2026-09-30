class_name RoomCodeLabel
extends Label
## Código de la sala online, en amarillo arriba a la izquierda (sobre la barra superior).
## Se esconde si la partida no es online (no hay código).

const POSITION: Vector2 = Vector2(24.0, 8.0)
const COLOR: Color = Color(1.0, 0.86, 0.2)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = POSITION
	add_theme_font_size_override("font_size", 48)
	add_theme_color_override("font_color", COLOR)
	add_theme_color_override("font_outline_color", Color(0.09, 0.07, 0.12))
	add_theme_constant_override("outline_size", 12)
	EventBus.partida_iniciada.connect(func(_mode: int, _seed: int) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	text = NetworkManager.room_code
	visible = text != ""
