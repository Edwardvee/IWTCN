class_name UnlockPlotCommand
extends GameCommand
## Comprar un plot bloqueado con oro (coste en rules.plot_costs).

var plot_index: int = -1


func _init(p_player_id: int, p_plot_index: int, p_source: GameCommand.Source = GameCommand.Source.LOCAL_PLAYER) -> void:
	player_id = p_player_id
	plot_index = p_plot_index
	source = p_source


func get_type() -> StringName:
	return &"unlock_plot"


func validate(processor: CommandProcessor) -> String:
	var grid: GridManager = processor.get_grid(player_id)
	if grid == null:
		return Reason.make("Grid no encontrado")
	var reason: String = grid.can_unlock(plot_index)
	if reason != "":
		return reason
	var cost: int = processor.get_database().rules.get_plot_cost(plot_index)
	if not EconomyManager.has_gold(player_id, cost):
		return Reason.make("Oro insuficiente (%d)", [cost])
	return ""


func apply(processor: CommandProcessor) -> bool:
	var cost: int = processor.get_database().rules.get_plot_cost(plot_index)
	if not EconomyManager.spend_gold(player_id, cost):
		return false
	processor.get_grid(player_id).unlock(plot_index)
	return true
