class_name RerollShopCommand
extends GameCommand
## Pagar el coste actual de reroll para renovar la tienda.


func _init(p_player_id: int, p_source: GameCommand.Source = GameCommand.Source.LOCAL_PLAYER) -> void:
	player_id = p_player_id
	source = p_source


func get_type() -> StringName:
	return &"reroll_shop"


func validate(processor: CommandProcessor) -> String:
	var draft: DraftManager = processor.get_draft()
	if draft == null:
		return "Tienda no disponible"
	var cost: int = draft.get_reroll_cost(player_id)
	if not EconomyManager.has_gold(player_id, cost):
		return "Oro insuficiente para reroll (%d)" % cost
	return ""


func apply(processor: CommandProcessor) -> bool:
	var draft: DraftManager = processor.get_draft()
	if not EconomyManager.spend_gold(player_id, draft.get_reroll_cost(player_id)):
		return false
	draft.apply_reroll(player_id)
	return true
