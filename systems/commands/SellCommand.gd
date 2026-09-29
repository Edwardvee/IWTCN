class_name SellCommand
extends GameCommand
## Vender (martillo) la estructura de un slot: libera el slot y devuelve
## rules.sell_refund_ratio del oro invertido.

var slot_index: int = -1


func _init(p_player_id: int, p_slot_index: int, p_source: GameCommand.Source = GameCommand.Source.LOCAL_PLAYER) -> void:
	player_id = p_player_id
	slot_index = p_slot_index
	source = p_source


func get_type() -> StringName:
	return &"sell"


func validate(processor: CommandProcessor) -> String:
	var grid: GridManager = processor.get_grid(player_id)
	if grid == null:
		return Reason.make("Grid no encontrado")
	return grid.can_sell(slot_index)


func apply(processor: CommandProcessor) -> bool:
	var grid: GridManager = processor.get_grid(player_id)
	var rules: GameRules = processor.get_database().rules
	var refund: int = rules.get_sell_refund(grid.get_invested_gold(slot_index))
	grid.sell(slot_index, refund)
	return EconomyManager.add_gold(player_id, refund)
