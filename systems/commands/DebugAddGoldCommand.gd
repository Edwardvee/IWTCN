class_name DebugAddGoldCommand
extends GameCommand
## Solo panel debug: añade oro a un jugador para probar sistemas rápidamente.
## El CommandProcessor rechaza la fuente DEBUG fuera de builds de depuración.

var amount: int = 0


func _init(p_player_id: int, p_amount: int) -> void:
	player_id = p_player_id
	amount = p_amount
	source = GameCommand.Source.DEBUG


func get_type() -> StringName:
	return &"debug_add_gold"


func validate(_processor: CommandProcessor) -> String:
	if source != GameCommand.Source.DEBUG:
		return Reason.make("Comando exclusivo de debug")
	if amount <= 0:
		return Reason.make("Cantidad inválida")
	return ""


func apply(_processor: CommandProcessor) -> bool:
	return EconomyManager.add_gold(player_id, amount)
