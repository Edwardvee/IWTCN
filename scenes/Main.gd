extends Node
## Raíz de la partida (composition root): conecta los sistemas de la escena
## entre sí y con GameManager, y arranca el match.

@export var game_mode: MatchTypes.GameMode = MatchTypes.GameMode.VS_AI
## 0 = generar una semilla nueva. Cualquier otro valor reproduce la partida.
@export var match_seed: int = 0

@onready var _command_processor: CommandProcessor = $Systems/CommandProcessor
@onready var _draft: DraftManager = $Systems/DraftManager
@onready var _player_grid: GridManager = $World/PlayerGrid
@onready var _enemy_grid: GridManager = $World/EnemyGrid
@onready var _local_input: LocalInputController = $World/LocalInput
@onready var _lane: LaneManager = $World/Lane
@onready var _camera: CameraDragController = $Camera2D
@onready var _shop_panel: ShopPanel = $UI/HUD/BottomBar
@onready var _ai: AIController = $Systems/AIController


func _ready() -> void:
	for grid: GridManager in [_player_grid, _enemy_grid]:
		grid.lane = _lane
		_command_processor.register_grid(grid)
		_local_input.register_grid(grid)
	_command_processor.register_lane(_lane)
	_command_processor.register_draft(_draft)
	_local_input.lane = _lane
	_shop_panel.connect_input(_local_input)
	# Mientras se arrastra una carta, la cámara no se mueve.
	_shop_panel.card_drag_started.connect(func() -> void: _camera.input_enabled = false)
	_shop_panel.card_drag_finished.connect(func() -> void: _camera.input_enabled = true)
	GameManager.register_command_processor(_command_processor)
	# En VS AI la IA controla el asiento rival con las mismas vías que el jugador.
	var ai_player: int = MatchTypes.opponent_of(GameManager.local_player_id)
	var ai_grid: GridManager = _enemy_grid if ai_player == _enemy_grid.player_id else _player_grid
	_ai.setup(ai_player, _draft, ai_grid, _lane)
	_ai.enabled = game_mode == MatchTypes.GameMode.VS_AI

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
