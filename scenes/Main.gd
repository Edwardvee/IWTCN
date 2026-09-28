extends Node
## Raíz de la partida (composition root): conecta los sistemas de la escena
## entre sí y con GameManager, y arranca el match.

@export var game_mode: MatchTypes.GameMode = MatchTypes.GameMode.VS_AI
## 0 = generar una semilla nueva. Cualquier otro valor reproduce la partida.
@export var match_seed: int = 0

@onready var _command_processor: CommandProcessor = $Systems/CommandProcessor
@onready var _player_grid: GridManager = $World/PlayerGrid
@onready var _enemy_grid: GridManager = $World/EnemyGrid
@onready var _local_input: LocalInputController = $World/LocalInput
@onready var _lane: LaneManager = $World/Lane


func _ready() -> void:
	for grid: GridManager in [_player_grid, _enemy_grid]:
		_command_processor.register_grid(grid)
		_local_input.register_grid(grid)
	_command_processor.register_lane(_lane)
	GameManager.register_command_processor(_command_processor)

	var seed_value: int = match_seed
	if seed_value == 0:
		seed_value = _generate_seed()
	GameManager.start_match(game_mode, seed_value)


func _exit_tree() -> void:
	GameManager.register_command_processor(null)


func _generate_seed() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return maxi(1, rng.randi())
