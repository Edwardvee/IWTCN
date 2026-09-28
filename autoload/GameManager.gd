extends Node
## Ciclo de vida de la partida, modo de juego y autoridad.
##
## No contiene reglas de gameplay: crea el MatchState, avanza el reloj
## de partida y responde quién tiene autoridad para modificar el estado.

var game_mode: MatchTypes.GameMode = MatchTypes.GameMode.VS_AI
var match_phase: MatchTypes.MatchPhase = MatchTypes.MatchPhase.IDLE
## Asiento del jugador que usa este dispositivo (solo lo usan UI/input).
var local_player_id: int = MatchTypes.PLAYER_BOTTOM
var match_state: MatchState = null

var _next_match_id: int = 1


func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if match_phase != MatchTypes.MatchPhase.RUNNING or not is_authority():
		return
	match_state.match_time += delta


func start_match(mode: MatchTypes.GameMode, match_seed: int) -> void:
	game_mode = mode
	match_state = MatchState.new(_next_match_id, match_seed, MatchTypes.PLAYER_COUNT)
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
