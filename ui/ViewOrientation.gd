class_name ViewOrientation
extends RefCounted
## Orientación de la vista local. El jugador de arriba (player 1) ve el mundo
## girado 180° para tener siempre su reino abajo. Solo presentación: la
## simulación y las coordenadas del mundo no cambian.


static func is_flipped() -> bool:
	return GameManager.local_player_id == MatchTypes.PLAYER_TOP


## Mantiene un texto del mundo legible cuando la vista está girada.
static func orient(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
	control.rotation = PI if is_flipped() else 0.0
