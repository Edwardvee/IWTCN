class_name MatchState
extends RefCounted
## Estado lógico completo de una partida. Serializable con to_dict()
## para snapshots de red y tests. No contiene nodos de escena.

var match_id: int = 0
var match_seed: int = 0
var match_time: float = 0.0
var players: Array[PlayerState] = []
## Contador de ids lógicos de entidad (edificios, unidades). Estable entre
## máquinas, a diferencia del instance_id de Godot.
var next_entity_id: int = 1
## Única fuente de azar de la partida (tienda, combate, IA).
var random: MatchRandom
## Ganador al terminar (MatchTypes.NO_PLAYER = empate o partida en curso).
var winner_player_id: int = MatchTypes.NO_PLAYER


func _init(p_match_id: int, p_match_seed: int, player_count: int, rules: GameRules) -> void:
	match_id = p_match_id
	match_seed = p_match_seed
	random = MatchRandom.new(p_match_seed)
	for player_id: int in player_count:
		players.append(PlayerState.new(player_id, rules))


func get_player(player_id: int) -> PlayerState:
	if player_id < 0 or player_id >= players.size():
		return null
	return players[player_id]


func allocate_entity_id() -> int:
	var entity_id: int = next_entity_id
	next_entity_id += 1
	return entity_id


func to_dict() -> Dictionary:
	var player_dicts: Array[Dictionary] = []
	for player_state: PlayerState in players:
		player_dicts.append(player_state.to_dict())
	return {
		"match_id": match_id,
		"match_seed": match_seed,
		"match_time": match_time,
		"next_entity_id": next_entity_id,
		"winner_player_id": winner_player_id,
		"random": random.to_dict(),
		"players": player_dicts,
	}
