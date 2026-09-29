class_name ReplayPlayer
extends Node
## Reproduce una ReplayData aplicando sus snapshots con StateReplicator, igual
## que un cliente online. GameManager está en modo REPLAY (sin autoridad), así
## que ningún sistema simula: solo se presenta el estado grabado.

signal finished

var replicator: StateReplicator = null
var data: ReplayData = null
var playing: bool = true
## Multiplicador del reloj de reproducción (1, 2, 4, 8…).
var speed: float = 1.0
var time: float = 0.0

var _next_frame: int = 0
var _finished: bool = false


func start(p_data: ReplayData, p_replicator: StateReplicator) -> void:
	data = p_data
	replicator = p_replicator
	restart()


func restart() -> void:
	time = 0.0
	_next_frame = 0
	_finished = false
	playing = true
	replicator.reset()
	GameManager.match_races = data.get_races()
	GameManager.start_match(MatchTypes.GameMode.REPLAY, data.get_seed())


func get_duration() -> float:
	return data.get_duration() if data != null else 0.0


func is_finished() -> bool:
	return _finished


func _physics_process(delta: float) -> void:
	if data == null or not playing or _finished:
		return
	time = minf(time + delta * speed, get_duration())
	_apply_until(time)


## Salta a `target_time`. Hacia atrás reinicia y avanza rápido (los snapshots
## no son incrementales del todo: edificios y mejoras solo se acumulan).
func seek(target_time: float) -> void:
	if data == null:
		return
	target_time = clampf(target_time, 0.0, get_duration())
	var was_playing: bool = playing
	GameManager.suppress_effects = true
	if target_time < time or _finished:
		restart()
	time = target_time
	_apply_until(target_time)
	GameManager.suppress_effects = false
	if not _finished:
		playing = was_playing


func _apply_until(target_time: float) -> void:
	while _next_frame < data.frames.size() and float(data.frames[_next_frame]["t"]) <= target_time:
		replicator.apply_snapshot(data.frames[_next_frame]["s"])
		_next_frame += 1
	if _next_frame >= data.frames.size() and not _finished:
		_finished = true
		playing = false
		GameManager.end_match(data.get_winner())
		finished.emit()
