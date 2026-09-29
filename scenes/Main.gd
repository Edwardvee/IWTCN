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
@onready var _systems: Node = $Systems
@onready var _hud: Control = $UI/HUD

var _recorder: ReplayRecorder = null
var _replay_player: ReplayPlayer = null
var _spectator_bar: SpectatorBar = null
var _second_ai: AIController = null


func _ready() -> void:
	var mode: MatchTypes.GameMode = game_mode
	var seed_value: int = match_seed
	if GameManager.has_pending_match():
		seed_value = GameManager.consume_pending_match()
		mode = GameManager.game_mode
	else:
		GameManager.consume_pending_match()
		# Atajo de desarrollo: `-- --spectate` arranca IA contra IA directamente.
		if OS.get_cmdline_user_args().has("--spectate"):
			mode = MatchTypes.GameMode.SPECTATE
			GameManager.game_mode = mode

	if mode == MatchTypes.GameMode.REPLAY and GameManager.pending_replay == null:
		mode = MatchTypes.GameMode.VS_AI
		GameManager.game_mode = mode
	var replay: ReplayData = GameManager.pending_replay if mode == MatchTypes.GameMode.REPLAY else null
	if replay != null:
		seed_value = replay.get_seed()

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

	var floating_text: FloatingTextLayer = FloatingTextLayer.new()
	$World.add_child(floating_text)
	floating_text.setup(grids)
	_recorder = ReplayRecorder.new()
	_recorder.replicator = _replicator
	_systems.add_child(_recorder)

	# En VS AI la IA controla el asiento rival con las mismas vías que el jugador.
	var ai_player: int = MatchTypes.opponent_of(GameManager.local_player_id)
	_ai.setup(ai_player, _draft, _enemy_grid if ai_player == _enemy_grid.player_id else _player_grid, _lane)
	_ai.enabled = mode == MatchTypes.GameMode.VS_AI or mode == MatchTypes.GameMode.SPECTATE
	if mode == MatchTypes.GameMode.VS_AI:
		AIDifficulty.apply(_ai, GameManager.ai_difficulty)
	# Los comandos debug no existen online.
	if mode == MatchTypes.GameMode.ONLINE and is_instance_valid(_debug_panel):
		_debug_panel.visible = false

	if seed_value == 0:
		seed_value = _generate_seed()
	if GameManager.is_watching():
		_setup_watch_mode(mode, seed_value)
	if replay != null:
		_replay_player.start(replay, _replicator)
	else:
		GameManager.start_match(mode, seed_value)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	GameManager.suppress_effects = false
	GameManager.register_command_processor(null)
	NetworkManager.register_replicator(null)


## Espectador (IA contra IA), repetición y espectador online: sin tienda ni
## input, con barra de control. El asiento local sigue siendo el de abajo para
## reutilizar la vista.
func _setup_watch_mode(mode: MatchTypes.GameMode, seed_value: int) -> void:
	_shop_panel.visible = false
	_debug_panel.visible = false
	_local_input.set_process_unhandled_input(false)
	_camera.process_mode = Node.PROCESS_MODE_ALWAYS
	if mode == MatchTypes.GameMode.SPECTATE:
		_second_ai = AIController.new()
		_systems.add_child(_second_ai)
		_second_ai.setup(MatchTypes.PLAYER_BOTTOM, _draft, _player_grid, _lane)
		# Cada semilla enfrenta dos estilos de juego distintos.
		var profiles: Array[StringName] = RuleBasedStrategy.PROFILES
		_second_ai.strategy = RuleBasedStrategy.create(profiles[seed_value % profiles.size()])
		_ai.strategy = RuleBasedStrategy.create(profiles[(seed_value / profiles.size() + 1) % profiles.size()])
	var bar_kind: SpectatorBar.Kind = SpectatorBar.Kind.LOCAL
	if mode == MatchTypes.GameMode.REPLAY:
		bar_kind = SpectatorBar.Kind.REPLAY
	elif mode == MatchTypes.GameMode.ONLINE:
		bar_kind = SpectatorBar.Kind.LIVE
	_spectator_bar = SpectatorBar.new(bar_kind)
	_hud.add_child(_spectator_bar)
	_spectator_bar.exit_requested.connect(_on_watch_exit)
	if mode == MatchTypes.GameMode.ONLINE:
		return
	if mode == MatchTypes.GameMode.SPECTATE:
		_spectator_bar.pause_toggled.connect(func(paused: bool) -> void: get_tree().paused = paused)
		_spectator_bar.speed_selected.connect(func(speed: float) -> void: Engine.time_scale = speed)
		return
	_replay_player = ReplayPlayer.new()
	_systems.add_child(_replay_player)
	_spectator_bar.pause_toggled.connect(func(paused: bool) -> void: _replay_player.playing = not paused and not _replay_player.is_finished())
	_spectator_bar.speed_selected.connect(func(speed: float) -> void: _replay_player.speed = speed)
	_spectator_bar.seek_requested.connect(_replay_player.seek)
	_spectator_bar.restart_requested.connect(func() -> void:
		_replay_player.restart()
		_spectator_bar.reset_controls())
	_replay_player.finished.connect(func() -> void: _spectator_bar.set_progress(_replay_player.get_duration(), _replay_player.get_duration()))


func _process(_delta: float) -> void:
	if _replay_player != null and _spectator_bar != null:
		_spectator_bar.set_progress(_replay_player.time, _replay_player.get_duration())


func _on_watch_exit() -> void:
	NetworkManager.close()
	get_tree().change_scene_to_file(NetworkManager.MENU_SCENE)


func _generate_seed() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return maxi(1, rng.randi())
