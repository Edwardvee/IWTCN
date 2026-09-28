class_name MatchTypes
extends RefCounted
## Tipos y constantes compartidos por todos los sistemas de la partida.
##
## player_id 0 = reino inferior ("Player" en la escena).
## player_id 1 = reino superior ("Enemy" en la escena).
## Son asientos fijos del mundo, no "jugador local": en online, el cliente
## del player 1 verá la cámara invertida, pero la simulación no cambia.

enum GameMode { VS_AI, ONLINE }
enum MatchPhase { IDLE, RUNNING, ENDED }

const PLAYER_BOTTOM: int = 0
const PLAYER_TOP: int = 1
const PLAYER_COUNT: int = 2
const NO_PLAYER: int = -1


static func is_valid_player_id(player_id: int) -> bool:
	return player_id >= 0 and player_id < PLAYER_COUNT


static func opponent_of(player_id: int) -> int:
	if not is_valid_player_id(player_id):
		return NO_PLAYER
	return PLAYER_TOP if player_id == PLAYER_BOTTOM else PLAYER_BOTTOM


## Dirección de avance en el carril para las unidades de un jugador.
static func forward_direction(player_id: int) -> Vector2:
	match player_id:
		PLAYER_BOTTOM:
			return Vector2(0.0, -1.0)
		PLAYER_TOP:
			return Vector2(0.0, 1.0)
	push_error("MatchTypes.forward_direction: player_id inválido %d" % player_id)
	return Vector2.ZERO


static func game_mode_name(mode: GameMode) -> String:
	match mode:
		GameMode.VS_AI:
			return "VS AI"
		GameMode.ONLINE:
			return "ONLINE"
	return "UNKNOWN"
