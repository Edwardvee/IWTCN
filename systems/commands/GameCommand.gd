class_name GameCommand
extends RefCounted
## Base de todas las acciones de gameplay. Jugador local, IA, red y panel
## debug crean comandos; CommandProcessor los valida y los aplica con las
## mismas reglas, sea cual sea su origen.
##
## Un comando nunca trae valores decididos por el cliente (precio, daño...):
## solo ids e índices. La autoridad calcula el resto a partir de los datos.

enum Source { LOCAL_PLAYER, AI, NETWORK, DEBUG }

var player_id: int = MatchTypes.NO_PLAYER
var source: Source = Source.LOCAL_PLAYER


func get_type() -> StringName:
	return &"game_command"


## "" si el comando es aplicable; si no, el motivo del rechazo.
## Las subclases lo sobrescriben; la base rechaza para que un comando
## sin validación nunca se ejecute.
func validate(_processor: CommandProcessor) -> String:
	return Reason.make("Comando '%s' sin validación", [get_type()])


## Aplica el comando ya validado. Devuelve false si algo falló al aplicarlo.
func apply(_processor: CommandProcessor) -> bool:
	push_error("GameCommand.apply no implementado en '%s'" % get_type())
	return false
