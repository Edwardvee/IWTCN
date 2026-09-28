extends Control
## HUD principal. Solo lee estado (GameManager/EventBus); nunca lo modifica.

const REFRESH_INTERVAL: float = 0.25
const TOAST_DURATION: float = 2.0

var _refresh_accumulator: float = 0.0
var _toast_time_left: float = 0.0

@onready var _match_info: Label = %MatchInfo
@onready var _toast: Label = %Toast


func _ready() -> void:
	EventBus.partida_iniciada.connect(_on_partida_iniciada)
	EventBus.partida_terminada.connect(_on_partida_terminada)
	EventBus.comando_rechazado.connect(_on_comando_rechazado)
	_toast.visible = false
	_refresh()


func _process(delta: float) -> void:
	if _toast_time_left > 0.0:
		_toast_time_left -= delta
		if _toast_time_left <= 0.0:
			_toast.visible = false
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
	# Oro rival visible solo como información de desarrollo (VS AI).
	var opponent_id: int = MatchTypes.opponent_of(GameManager.local_player_id)
	_match_info.text = "%s · seed %d · %.1f s · rival: %d oro" % [
		MatchTypes.game_mode_name(GameManager.game_mode),
		state.match_seed,
		state.match_time,
		EconomyManager.get_gold(opponent_id),
	]


func show_toast(message: String) -> void:
	_toast.text = message
	_toast.visible = true
	_toast_time_left = TOAST_DURATION


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	_refresh()


func _on_partida_terminada(_ganador_player_id: int) -> void:
	_refresh()


func _on_comando_rechazado(player_id: int, _tipo_comando: StringName, motivo: String) -> void:
	# En builds de depuración se muestran también los rechazos del rival.
	if player_id != GameManager.local_player_id and not OS.is_debug_build():
		return
	show_toast(motivo)
