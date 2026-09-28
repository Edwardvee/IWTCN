extends Node
## Raíz de la partida (composition root): conecta los sistemas de la escena
## entre sí y con GameManager / NetworkManager, y arranca el match.
## Si el menú o la red dejaron una configuración, se usa; si no (F6 en el
## editor), arranca VS AI con los valores exportados.

@export var game_mode: MatchTypes.GameMode = MatchTypes.GameMode.VS_AI
## 0 = generar una semilla nueva. Cualquier otro valor reproduce la partida.
@export var match_seed: int = 0

@onready var _command_processor: CommandProcessor = $Systems/CommandProcessor
@onready var _draft: DraftManager = $Systems/DraftManager
@onready var _replicator: StateReplicator = $Systems/StateReplicator
@onready var _player_grid: GridManager = $World/PlayerGrid
@onready var _enemy_grid: GridManager = $World/EnemyGrid
@onready var _local_input: LocalInputController = $World/LocalInput
@onready var _lane: LaneManager = $World/Lane
@onready var _camera: CameraDragController = $Camera2D
@onready var _shop_panel: ShopPanel = $UI/HUD/BottomBar
@onready var _ai: AIController = $Systems/AIController
@onready var _debug_panel: Control = $UI/HUD/DebugPanel


func _ready() -> void:
	var mode: MatchTypes.GameMode = game_mode
	var seed_value: int = match_seed
	if GameManager.has_pending_match():
		seed_value = GameManager.consume_pending_match()
		mode = GameManager.game_mode
	else:
		GameManager.consume_pending_match()

	var grids: Array[GridManager] = [_player_grid, _enemy_grid]
	for grid: GridManager in grids:
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
	# El jugador de arriba ve el mundo girado 180°: su reino siempre abajo.
	_camera.set_flipped(ViewOrientation.is_flipped())
	_camera.focus_side(GameManager.local_player_id == MatchTypes.PLAYER_BOTTOM)
	GameManager.register_command_processor(_command_processor)
	_replicator.setup(_lane, grids)
	NetworkManager.register_replicator(_replicator)

	# En VS AI la IA controla el asiento rival con las mismas vías que el jugador.
	var ai_player: int = MatchTypes.opponent_of(GameManager.local_player_id)
	_ai.setup(ai_player, _draft, _enemy_grid if ai_player == _enemy_grid.player_id else _player_grid, _lane)
	_ai.enabled = mode == MatchTypes.GameMode.VS_AI
	# Los comandos debug no existen online.
	if mode == MatchTypes.GameMode.ONLINE and is_instance_valid(_debug_panel):
		_debug_panel.visible = false

	if seed_value == 0:
		seed_value = _generate_seed()
	GameManager.start_match(mode, seed_value)


func _exit_tree() -> void:
	GameManager.register_command_processor(null)
	NetworkManager.register_replicator(null)


func _generate_seed() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return maxi(1, rng.randi())
