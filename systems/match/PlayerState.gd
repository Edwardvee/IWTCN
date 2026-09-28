class_name PlayerState
extends RefCounted
## Estado lógico de un jugador dentro de una partida.
##
## REGLA: solo EconomyManager escribe `gold` y `base_income_timer`;
## solo GridManager modifica `grid`. El resto lo lee.

var player_id: int = MatchTypes.NO_PLAYER
var gold: int = 0
## Segundos acumulados hacia el próximo ingreso base.
var base_income_timer: float = 0.0
var grid: GridState


func _init(p_player_id: int, rules: GameRules) -> void:
	player_id = p_player_id
	var initial_plots: PackedInt32Array = rules.initial_unlocked_plots if rules != null else PackedInt32Array()
	grid = GridState.new(initial_plots)


func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"gold": gold,
		"base_income_timer": base_income_timer,
		"grid": grid.to_dict(),
	}
