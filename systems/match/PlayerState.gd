class_name PlayerState
extends RefCounted
## Estado lógico de un jugador dentro de una partida.
##
## REGLA: solo EconomyManager escribe `gold`. El resto lo lee.
## Los campos de edificios, buffs y tienda se añadirán en sus fases.

var player_id: int = MatchTypes.NO_PLAYER
var gold: int = 0


func _init(p_player_id: int) -> void:
	player_id = p_player_id


func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"gold": gold,
	}
