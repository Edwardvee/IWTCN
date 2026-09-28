class_name MatchRandom
extends RefCounted
## Fuente de aleatoriedad controlada de la partida.
##
## Cada sistema pide su propio stream (tienda por jugador, combate, IA).
## Todos derivan de la semilla de la partida con aritmética entera fija, así
## que la misma semilla reproduce exactamente los mismos resultados, y una
## tirada extra en un sistema no altera la secuencia de los demás.
## Ningún sistema de gameplay debe usar randi()/randf() globales.

const STREAM_SHOP: int = 0
const STREAM_COMBAT: int = 1
const STREAM_AI: int = 2

var match_seed: int = 0

var _generators: Dictionary[int, RandomNumberGenerator] = {}


func _init(p_match_seed: int) -> void:
	match_seed = p_match_seed


## Generador del stream `stream`, opcionalmente por jugador.
func get_stream(stream: int, player_id: int = MatchTypes.NO_PLAYER) -> RandomNumberGenerator:
	var key: int = stream * 16 + (player_id + 1)
	if not _generators.has(key):
		var generator: RandomNumberGenerator = RandomNumberGenerator.new()
		generator.seed = _derive_seed(key)
		_generators[key] = generator
	return _generators[key]


## Mezcla determinista de la semilla y la clave. Cada paso se limita a
## 31 bits antes de multiplicar para no desbordar nunca int64 (el
## desbordamiento no está garantizado igual en todas las plataformas).
func _derive_seed(key: int) -> int:
	var value: int = (absi(match_seed % 0x7FFFFFFF) * 1000003 + key * 7919 + 0x2545F491) & 0x7FFFFFFF
	value = ((value ^ (value >> 15)) * 0x2C1B3C6D) & 0x7FFFFFFF
	value = ((value ^ (value >> 12)) * 0x297A2D39) & 0x7FFFFFFF
	return value ^ (value >> 15)


func to_dict() -> Dictionary:
	var states: Dictionary = {}
	for key: int in _generators:
		states[key] = _generators[key].state
	return {"match_seed": match_seed, "streams": states}
