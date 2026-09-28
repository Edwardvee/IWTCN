extends Control
## HUD principal. Solo lee estado (GameManager/EventBus); nunca lo modifica.

const REFRESH_INTERVAL: float = 0.25

var _refresh_accumulator: float = 0.0

@onready var _match_info: Label = %MatchInfo


func _ready() -> void:
	EventBus.partida_iniciada.connect(_on_partida_iniciada)
	EventBus.partida_terminada.connect(_on_partida_terminada)
	_refresh()


func _process(delta: float) -> void:
	_refresh_accumulator += delta
	if _refresh_accumulator < REFRESH_INTERVAL:
		return
	_refresh_accumulator = 0.0
	_refresh()


func _refresh() -> void:
	var state: MatchState = GameManager.match_state
	if state == null:
		_match_info.text = "Sin partida"
		return
	_match_info.text = "%s · seed %d · %.1f s" % [
		MatchTypes.game_mode_name(GameManager.game_mode),
		state.match_seed,
		state.match_time,
	]


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	_refresh()


func _on_partida_terminada(_ganador_player_id: int) -> void:
	_refresh()
