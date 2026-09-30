class_name SurrenderCommand
extends GameCommand
## Rendirse: la partida termina y gana el rival. Online el invitado lo envía al
## anfitrión, que es quien termina la partida (como cualquier otro comando).


func _init(p_player_id: int, p_source: GameCommand.Source = GameCommand.Source.LOCAL_PLAYER) -> void:
	player_id = p_player_id
	source = p_source


func get_type() -> StringName:
	return &"surrender"


func validate(_processor: CommandProcessor) -> String:
	return ""


func apply(_processor: CommandProcessor) -> bool:
	GameManager.end_match(MatchTypes.opponent_of(player_id))
	return true
