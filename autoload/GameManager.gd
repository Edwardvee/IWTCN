extends Node
## Ciclo de vida de la partida, modo de juego y autoridad.
##
## No contiene reglas de gameplay: crea el MatchState, avanza el reloj
## de partida y responde quién tiene autoridad para modificar el estado.
## También carga el GameDatabase, la única fuente de datos del juego.

const DATABASE_PATH: String = "res://data/game_database.tres"

var database: GameDatabase = null
var game_mode: MatchTypes.GameMode = MatchTypes.GameMode.VS_AI
var match_phase: MatchTypes.MatchPhase = MatchTypes.MatchPhase.IDLE
## Asiento del jugador que usa este dispositivo (solo lo usan UI/input).
var local_player_id: int = MatchTypes.PLAYER_BOTTOM
var match_state: MatchState = null
## Las repeticiones lo activan al saltar en el tiempo: la presentación (números
## flotantes, avisos) se silencia mientras se aplican muchos snapshots seguidos.
var suppress_effects: bool = false
## Repetición pendiente de reproducir (la fija el menú) y última guardada.
var pending_replay: ReplayData = null
var last_replay_path: String = ""

var _next_match_id: int = 1
var _command_processor: CommandProcessor = null

# Configuración que el menú / la red dejan para la próxima escena de partida.
var _has_pending_match: bool = false
var _pending_mode: MatchTypes.GameMode = MatchTypes.GameMode.VS_AI
var _pending_seed: int = 0
var _pending_local_player: int = MatchTypes.PLAYER_BOTTOM


func _ready() -> void:
	set_physics_process(false)
	_load_database()


func _physics_process(delta: float) -> void:
	if match_phase != MatchTypes.MatchPhase.RUNNING or not is_authority():
		return
	match_state.match_time += delta


func start_match(mode: MatchTypes.GameMode, match_seed: int) -> void:
	game_mode = mode
	match_state = MatchState.new(_next_match_id, match_seed, MatchTypes.PLAYER_COUNT, get_rules())
	_next_match_id += 1
	match_phase = MatchTypes.MatchPhase.RUNNING
	set_physics_process(true)
	EventBus.partida_iniciada.emit(mode, match_seed)


## winner_player_id puede ser MatchTypes.NO_PLAYER (empate).
func end_match(winner_player_id: int) -> void:
	if match_phase != MatchTypes.MatchPhase.RUNNING:
		return
	match_phase = MatchTypes.MatchPhase.ENDED
	match_state.winner_player_id = winner_player_id
	set_physics_process(false)
	EventBus.partida_terminada.emit(winner_player_id)


## En VS AI y espectador la simulación local es la autoridad. En online solo
## el anfitrión. Una repetición nunca simula: solo presenta snapshots grabados.
func is_authority() -> bool:
	match game_mode:
		MatchTypes.GameMode.VS_AI, MatchTypes.GameMode.SPECTATE:
			return true
		MatchTypes.GameMode.REPLAY:
			return false
	return not NetworkManager.is_client()


## true si el usuario solo mira: espectador local, repetición o espectador
## online (una partida ONLINE vista desde una sala como espectador).
func is_watching() -> bool:
	return MatchTypes.is_watch_mode(game_mode) or (game_mode == MatchTypes.GameMode.ONLINE and NetworkManager.is_spectator())


func is_match_running() -> bool:
	return match_phase == MatchTypes.MatchPhase.RUNNING and match_state != null


func get_player_state(player_id: int) -> PlayerState:
	if match_state == null:
		return null
	return match_state.get_player(player_id)


## El menú o la red fijan cómo arrancará la próxima escena de partida.
func configure_next_match(mode: MatchTypes.GameMode, match_seed: int, p_local_player_id: int) -> void:
	_has_pending_match = true
	_pending_mode = mode
	_pending_seed = match_seed
	_pending_local_player = p_local_player_id


func has_pending_match() -> bool:
	return _has_pending_match


## Aplica la configuración pendiente (modo y asiento local) y devuelve la
## semilla (0 = generar una). Sin configuración: VS AI como player 0.
func consume_pending_match() -> int:
	if not _has_pending_match:
		local_player_id = MatchTypes.PLAYER_BOTTOM
		return 0
	_has_pending_match = false
	game_mode = _pending_mode
	local_player_id = _pending_local_player
	return _pending_seed


## La escena de partida registra aquí su CommandProcessor (null para quitarlo).
func register_command_processor(processor: CommandProcessor) -> void:
	_command_processor = processor


## Entrada única de acciones para jugador local, IA, red y debug.
## En un cliente online el comando se envía al servidor en lugar de ejecutarse.
func submit_command(command: GameCommand) -> bool:
	if game_mode == MatchTypes.GameMode.ONLINE and not is_authority():
		return NetworkManager.send_command(command)
	if _command_processor == null or not is_instance_valid(_command_processor):
		push_error("GameManager.submit_command: no hay CommandProcessor registrado")
		return false
	return _command_processor.submit(command)


func get_rules() -> GameRules:
	if database == null:
		return null
	return database.rules


func _load_database() -> void:
	database = load(DATABASE_PATH) as GameDatabase
	if database == null:
		push_error("GameManager: no se pudo cargar %s" % DATABASE_PATH)
		return
	database.build_index()
	for error: String in database.get_validation_errors():
		push_error(error)
