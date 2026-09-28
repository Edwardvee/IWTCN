class_name CommandProcessor
extends Node
## Punto único de entrada de acciones de gameplay en la autoridad.
##
##   origen (jugador/IA/red/debug) → GameCommand → permisos → validate → apply
##
## En online, el cliente enviará el comando al servidor y será el
## CommandProcessor del servidor quien lo ejecute con estas mismas reglas.

var _grids: Dictionary[int, GridManager] = {}
var _lane: LaneManager = null


func register_grid(grid: GridManager) -> void:
	_grids[grid.player_id] = grid


func register_lane(lane: LaneManager) -> void:
	_lane = lane


func get_lane() -> LaneManager:
	return _lane if _lane != null and is_instance_valid(_lane) else null


func get_grid(player_id: int) -> GridManager:
	var grid: GridManager = _grids.get(player_id, null)
	if grid != null and not is_instance_valid(grid):
		return null
	return grid


func get_database() -> GameDatabase:
	return GameManager.database


func submit(command: GameCommand) -> bool:
	if command == null:
		return false
	var reason: String = _check_permissions(command)
	if reason == "":
		reason = command.validate(self)
	if reason != "":
		_reject(command, reason)
		return false
	if not command.apply(self):
		_reject(command, "Error al aplicar")
		return false
	return true


func _check_permissions(command: GameCommand) -> String:
	if not GameManager.is_authority():
		return "Sin autoridad"
	if not GameManager.is_match_running():
		return "La partida no está en curso"
	if get_database() == null:
		return "Sin base de datos"
	if not MatchTypes.is_valid_player_id(command.player_id):
		return "Jugador inválido"
	match command.source:
		GameCommand.Source.LOCAL_PLAYER:
			if command.player_id != GameManager.local_player_id:
				return "No puedes actuar por otro jugador"
		GameCommand.Source.AI:
			if GameManager.game_mode != MatchTypes.GameMode.VS_AI or command.player_id == GameManager.local_player_id:
				return "La IA solo controla al rival en VS AI"
		GameCommand.Source.DEBUG:
			if not OS.is_debug_build():
				return "Comandos debug deshabilitados"
		GameCommand.Source.NETWORK:
			# La correspondencia peer → player_id se validará en la fase online.
			if GameManager.game_mode != MatchTypes.GameMode.ONLINE:
				return "Comando de red fuera de partida online"
	return ""


func _reject(command: GameCommand, reason: String) -> void:
	EventBus.comando_rechazado.emit(command.player_id, command.get_type(), reason)
