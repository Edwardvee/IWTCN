extends Node
## Raíz de la partida: configura el modo y arranca el match.
## En fases posteriores conectará los sistemas de la escena con GameManager.

@export var game_mode: MatchTypes.GameMode = MatchTypes.GameMode.VS_AI
## 0 = generar una semilla nueva. Cualquier otro valor reproduce la partida.
@export var match_seed: int = 0


func _ready() -> void:
	var seed_value: int = match_seed
	if seed_value == 0:
		seed_value = _generate_seed()
	GameManager.start_match(game_mode, seed_value)


func _generate_seed() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return maxi(1, rng.randi())
