class_name ReplayRecorder
extends Node
## Graba la partida de la autoridad (VS IA, espectador local o anfitrión
## online) tomando un snapshot cada FRAME_INTERVAL segundos de partida y lo
## guarda al terminar. Solo lee estado; nunca lo modifica.

const FRAME_INTERVAL: float = 0.1
## Tope de frames (≈ 20 min) para acotar memoria en partidas larguísimas.
const MAX_FRAMES: int = 12000

var replicator: StateReplicator = null
var enabled: bool = true
## Ruta de la última repetición guardada en esta sesión ("" si no hay).
var last_saved_path: String = ""

var _data: ReplayData = null
## Qué partes del estado ya se guardaron (los frames solo repiten lo que cambia).
var _delta_cache: Dictionary = {}
var _next_capture_time: float = 0.0


func _ready() -> void:
	EventBus.partida_iniciada.connect(_on_partida_iniciada)
	EventBus.partida_terminada.connect(_on_partida_terminada)


func is_recording() -> bool:
	return _data != null


func get_frame_count() -> int:
	return _data.frames.size() if _data != null else 0


func _physics_process(_delta: float) -> void:
	if _data == null or not GameManager.is_match_running():
		return
	var match_time: float = GameManager.match_state.match_time
	if match_time >= _next_capture_time and _data.frames.size() < MAX_FRAMES:
		_capture(match_time)
		_next_capture_time = match_time + FRAME_INTERVAL


func _capture(match_time: float) -> void:
	# El primer frame va completo; los demás omiten lo que no cambió. El
	# ReplayPlayer los aplica siempre en orden desde el principio.
	_data.add_frame(match_time, replicator.build_delta_snapshot(_delta_cache))


func _on_partida_iniciada(mode: int, seed_value: int) -> void:
	_data = null
	if not enabled or replicator == null or not GameManager.is_authority() or mode == MatchTypes.GameMode.REPLAY:
		return
	_delta_cache = {}
	_data = ReplayData.new({
		"seed": seed_value,
		"mode": mode,
		"local_player": GameManager.local_player_id,
		"races": GameManager.match_races.duplicate(),
		"date": Time.get_datetime_string_from_system(),
	})
	_next_capture_time = 0.0


func _on_partida_terminada(winner_player_id: int) -> void:
	if _data == null:
		return
	_capture(GameManager.match_state.match_time)
	_data.meta["winner"] = winner_player_id
	last_saved_path = _data.save()
	GameManager.last_replay_path = last_saved_path
	_data = null
