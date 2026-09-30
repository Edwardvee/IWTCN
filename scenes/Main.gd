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
@onready var _spell_panel: SpellPanel = $UI/HUD/SpellPanel
@onready var _ai: AIController = $Systems/AIController
@onready var _debug_panel: Control = $UI/HUD/DebugPanel
@onready var _systems: Node = $Systems
@onready var _hud: Control = $UI/HUD

## Dónde queda el edificio modificador respecto al castillo del jugador de abajo (a su izquierda,
## sobre sus plots); el del rival ocupa el punto simétrico respecto a su castillo.
## Cámara lenta al caer un castillo: velocidad del tiempo y segundos REALES que dura.
const SLOWMO_SCALE: float = 0.25
const SLOWMO_SECONDS: float = 1.8
const MOD_BUILDING_OFFSET: Vector2 = Vector2(-363.0, -135.0)

var _recorder: ReplayRecorder = null
var _replay_player: ReplayPlayer = null
var _spectator_bar: SpectatorBar = null
var _second_ai: AIController = null
var _mod_views: Array[ModBuildingView] = []


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
	_spell_panel.connect_input(_local_input)
	_add_match_info()
	_spell_panel.drag_started.connect(func() -> void: _camera.input_enabled = false)
	_spell_panel.drag_finished.connect(func() -> void: _camera.input_enabled = true)
	# El jugador de arriba ve el mundo girado 180°: su reino siempre abajo.
	_camera.set_flipped(ViewOrientation.is_flipped())
	_camera.focus_side(GameManager.local_player_id == MatchTypes.PLAYER_BOTTOM)
	GameManager.register_command_processor(_command_processor)
	EventBus.partida_terminada.connect(_on_match_ended)
	_replicator.setup(_lane, grids)
	NetworkManager.register_replicator(_replicator)

	var floating_text: FloatingTextLayer = FloatingTextLayer.new()
	$World.add_child(floating_text)
	floating_text.setup(grids)
	$World.add_child(SlashEffects.new())
	$World.add_child(SpellEffects.new())
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

	# Atajo de desarrollo: `-- --seed=16` fija la semilla (y con ella las razas del rival).
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seed=") and argument.trim_prefix("--seed=").is_valid_int():
			seed_value = argument.trim_prefix("--seed=").to_int()
	if seed_value == 0:
		seed_value = _generate_seed()
	_assign_races(mode, seed_value, replay)
	_assign_mods(mode, seed_value, replay)
	if GameManager.is_watching():
		_setup_watch_mode(mode, seed_value)
	if replay != null:
		_replay_player.start(replay, _replicator)
	else:
		# Cuenta atrás 3·2·1 antes de jugar (no para quien entra a mirar una partida online en curso).
		var with_countdown: bool = not (mode == MatchTypes.GameMode.ONLINE and GameManager.is_watching())
		GameManager.start_match(mode, seed_value, with_countdown)
		if with_countdown:
			_start_intro()


## Razas de cada asiento [abajo, arriba]. Online las fija NetworkManager; una repetición
## usa las que grabó.
func _assign_races(mode: MatchTypes.GameMode, seed_value: int, replay: ReplayData) -> void:
	if mode == MatchTypes.GameMode.ONLINE:
		return
	if replay != null:
		GameManager.match_races = replay.get_races()
		return
	var races: Array[RaceData] = GameManager.database.races
	# El rival (o ambos bandos al mirar IA contra IA) usa una raza según la semilla.
	var rival: StringName = races[(seed_value / 7) % races.size()].id
	if mode == MatchTypes.GameMode.SPECTATE:
		GameManager.match_races = [races[seed_value % races.size()].id, rival]
	elif GameManager.local_player_id == MatchTypes.PLAYER_BOTTOM:
		GameManager.match_races = [GameManager.player_race, rival]
	else:
		GameManager.match_races = [rival, GameManager.player_race]


## Edificios modificadores [abajo, arriba]. Online los fija NetworkManager y una repetición
## los recibe en sus snapshots. En VS IA el jugador trae el suyo del selector (o uno según
## la semilla si arrancó sin pasar por él) y el rival uno según la semilla.
func _assign_mods(mode: MatchTypes.GameMode, seed_value: int, replay: ReplayData) -> void:
	if mode == MatchTypes.GameMode.ONLINE:
		return
	if replay != null:
		GameManager.match_mods = []
		return
	var rival: StringName = ModBuildings.pick_from_seed(seed_value, 13)
	if mode == MatchTypes.GameMode.SPECTATE:
		GameManager.match_mods = [ModBuildings.pick_from_seed(seed_value, 3), rival]
		return
	var own: StringName = GameManager.player_mod if ModBuildings.is_valid(GameManager.player_mod) else ModBuildings.pick_from_seed(seed_value, 5)
	if GameManager.local_player_id == MatchTypes.PLAYER_BOTTOM:
		GameManager.match_mods = [own, rival]
	else:
		GameManager.match_mods = [rival, own]


## Los edificios modificadores (en el mundo, junto a cada castillo), el tiempo de partida bajo
## el contador de tropas y, online, el código de sala arriba a la izquierda.
func _add_match_info() -> void:
	var castle_bottom: Vector2 = $World/PlayerCastle.position
	var castle_top: Vector2 = $World/EnemyCastle.position
	for placement: Array in [[MatchTypes.PLAYER_BOTTOM, castle_bottom + MOD_BUILDING_OFFSET], [MatchTypes.PLAYER_TOP, castle_top - MOD_BUILDING_OFFSET]]:
		var view: ModBuildingView = ModBuildingView.new()
		$World.add_child(view)
		view.setup(placement[0], placement[1])
		_mod_views.append(view)
		_local_input.register_mod_view(view)
	var clock: MatchClock = MatchClock.new()
	clock.name = "MatchClock"
	_hud.add_child(clock)
	var room_code: RoomCodeLabel = RoomCodeLabel.new()
	room_code.name = "RoomCodeLabel"
	_hud.add_child(room_code)
	# Por debajo del menú de pausa y del panel de fin de partida.
	var pause_index: int = _hud.get_node("PauseMenu").get_index()
	for node: Control in [clock, room_code]:
		_hud.move_child(node, pause_index)
	# Al arrastrar una estructura hacia los hechizos se vuelven transparentes.
	_shop_panel.structure_drag_moved.connect(_spell_panel.set_drag_pointer)


## Cuando un castillo cae, cámara lenta: el tiempo se frena, la cámara se acerca al castillo
## derrumbado (que se sacude y suelta escombros, ver Castle.gd) y el panel de fin de partida
## espera a que pase. Una rendición no derriba ningún castillo, así que no la activa.
func _on_match_ended(_winner_id: int) -> void:
	if GameManager.suppress_effects:
		return
	var fallen_y: float = INF
	for player_state: PlayerState in GameManager.match_state.players:
		if not player_state.is_castle_alive():
			fallen_y = ($World/PlayerCastle if player_state.player_id == MatchTypes.PLAYER_BOTTOM else $World/EnemyCastle).position.y
	if fallen_y == INF:
		return
	var previous_scale: float = Engine.time_scale
	Engine.time_scale = SLOWMO_SCALE
	_camera.pan_to(fallen_y, SLOWMO_SECONDS * 0.6)
	get_tree().create_timer(SLOWMO_SECONDS, true, false, true).timeout.connect(func() -> void:
		if is_equal_approx(Engine.time_scale, SLOWMO_SCALE):
			Engine.time_scale = previous_scale)


func _start_intro() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var intro: MatchIntro = MatchIntro.new()
	layer.add_child(intro)
	intro.finished.connect(func() -> void:
		GameManager.begin_play()
		layer.queue_free())


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
