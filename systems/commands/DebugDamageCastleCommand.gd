class_name DebugDamageCastleCommand
extends GameCommand
## Solo panel debug: daña el castillo de `player_id` para probar victoria/derrota.
## La comprobación de fin de partida ocurre en el siguiente tick del carril.

var amount: float = 0.0


func _init(p_player_id: int, p_amount: float) -> void:
	player_id = p_player_id
	amount = p_amount
	source = GameCommand.Source.DEBUG


func get_type() -> StringName:
	return &"debug_damage_castle"


func validate(processor: CommandProcessor) -> String:
	if source != GameCommand.Source.DEBUG:
		return "Comando exclusivo de debug"
	if processor.get_lane() == null:
		return "Carril no encontrado"
	return "" if amount > 0.0 else "Cantidad inválida"


func apply(processor: CommandProcessor) -> bool:
	processor.get_lane().damage_castle(player_id, amount)
	return true
