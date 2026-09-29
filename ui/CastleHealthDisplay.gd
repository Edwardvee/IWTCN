extends Label
## Vida de ambos castillos en el HUD, desde el punto de vista del jugador local.
## Solo lee: escucha castillo_danado y partida_iniciada.


func _ready() -> void:
	EventBus.castillo_danado.connect(_on_castillo_danado)
	EventBus.partida_iniciada.connect(_on_partida_iniciada)
	_refresh()


func _refresh() -> void:
	var own: PlayerState = GameManager.get_player_state(GameManager.local_player_id)
	var rival: PlayerState = GameManager.get_player_state(MatchTypes.opponent_of(GameManager.local_player_id))
	if own == null or rival == null:
		text = ""
		return
	if GameManager.is_watching():
		text = "Castillo abajo: %d   ·   arriba: %d" % [ceili(own.castle_hp), ceili(rival.castle_hp)]
		return
	text = "Tu castillo: %d   ·   Rival: %d" % [ceili(own.castle_hp), ceili(rival.castle_hp)]


func _on_castillo_danado(_player_id: int, _vida_actual: float, _vida_maxima: float) -> void:
	_refresh()


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	_refresh()
