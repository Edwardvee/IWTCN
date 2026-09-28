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

var _next_match_id: int = 1
var _command_processor: CommandProcessor = null


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
	set_physics_process(false)
	EventBus.partida_terminada.emit(winner_player_id)


## En VS AI la simulación local es la autoridad. En online solo el servidor.
## Con el OfflineMultiplayerPeer por defecto, is_server() devuelve true.
func is_authority() -> bool:
	if game_mode == MatchTypes.GameMode.VS_AI:
		return true
	return multiplayer.is_server()


func is_match_running() -> bool:
	return match_phase == MatchTypes.MatchPhase.RUNNING and match_state != null


func get_player_state(player_id: int) -> PlayerState:
	if match_state == null:
		return null
	return match_state.get_player(player_id)


## La escena de partida registra aquí su CommandProcessor (null para quitarlo).
func register_command_processor(processor: CommandProcessor) -> void:
	_command_processor = processor


## Entrada única de acciones para jugador local, IA y debug.
## En online, aquí se enviará el comando al servidor en lugar de ejecutarlo.
func submit_command(command: GameCommand) -> bool:
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
