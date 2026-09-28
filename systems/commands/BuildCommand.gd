class_name BuildCommand
extends GameCommand
## SOLO DEBUG: construye cualquier carta de estructura sin pasar por la tienda
## (cobra su coste). Jugador e IA construyen con PlayCardCommand, que exige
## que la carta esté en su oferta.

var card_id: StringName = &""
var slot_index: int = -1


func _init(p_player_id: int, p_card_id: StringName, p_slot_index: int, p_source: GameCommand.Source = GameCommand.Source.LOCAL_PLAYER) -> void:
	player_id = p_player_id
	card_id = p_card_id
	slot_index = p_slot_index
	source = p_source


func get_type() -> StringName:
	return &"build"


func validate(processor: CommandProcessor) -> String:
	if source != GameCommand.Source.DEBUG:
		return "Construye arrastrando una carta de la tienda"
	var card: CardData = processor.get_database().get_card(card_id)
	if card == null:
		return "Carta desconocida"
	if card.card_type != CardData.CardType.STRUCTURE or card.structure == null:
		return "La carta no es una estructura"
	var grid: GridManager = processor.get_grid(player_id)
	if grid == null:
		return "Grid no encontrado"
	var reason: String = grid.can_build(slot_index, card.structure)
	if reason != "":
		return reason
	var cost: int = EconomyManager.get_card_cost(player_id, card)
	if not EconomyManager.has_gold(player_id, cost):
		return "Oro insuficiente (%d)" % cost
	return ""


func apply(processor: CommandProcessor) -> bool:
	var card: CardData = processor.get_database().get_card(card_id)
	var cost: int = EconomyManager.get_card_cost(player_id, card)
	if not EconomyManager.spend_gold(player_id, cost):
		return false
	return processor.get_grid(player_id).build(slot_index, card.structure, cost) != null
