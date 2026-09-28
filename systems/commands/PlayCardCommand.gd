class_name PlayCardCommand
extends GameCommand
## Jugar (comprar) una carta de la tienda del jugador.
##   STRUCTURE   → se construye en slot_index (el cliente lo resuelve al soltar
##                 sobre un plot; la autoridad valida que el slot sea válido)
##   DIRECT_UNIT → aparecen unit_count unidades en deploy_position (mitad propia)
##   GLOBAL_BUFF → Fase 10
## card_id acompaña a offer_index para detectar ofertas obsoletas (la tienda
## cambió entre el arrastre y la llegada del comando).

var offer_index: int = -1
var card_id: StringName = &""
var slot_index: int = -1
var deploy_position: Vector2 = Vector2.ZERO


func _init(p_player_id: int, p_offer_index: int, p_card_id: StringName, p_slot_index: int = -1,
		p_deploy_position: Vector2 = Vector2.ZERO, p_source: GameCommand.Source = GameCommand.Source.LOCAL_PLAYER) -> void:
	player_id = p_player_id
	offer_index = p_offer_index
	card_id = p_card_id
	slot_index = p_slot_index
	deploy_position = p_deploy_position
	source = p_source


func get_type() -> StringName:
	return &"play_card"


func validate(processor: CommandProcessor) -> String:
	var draft: DraftManager = processor.get_draft()
	if draft == null:
		return "Tienda no disponible"
	if card_id == &"" or draft.get_offer_card_id(player_id, offer_index) != card_id:
		return "La carta ya no está en la tienda"
	var card: CardData = processor.get_database().get_card(card_id)
	if card == null:
		return "Carta desconocida"
	if not EconomyManager.has_gold(player_id, card.cost):
		return "Oro insuficiente (%d)" % card.cost
	match card.card_type:
		CardData.CardType.STRUCTURE:
			var grid: GridManager = processor.get_grid(player_id)
			if grid == null:
				return "Grid no encontrado"
			if slot_index < 0:
				return "Suelta la estructura en un plot desbloqueado con espacio"
			return grid.can_build(slot_index, card.structure)
		CardData.CardType.DIRECT_UNIT:
			var lane: LaneManager = processor.get_lane()
			if lane == null:
				return "Carril no encontrado"
			if not lane.is_valid_deploy_position(player_id, deploy_position):
				return "Suelta las unidades en tu mitad del carril"
			return ""
	return "Tipo de carta no disponible todavía"


func apply(processor: CommandProcessor) -> bool:
	var card: CardData = processor.get_database().get_card(card_id)
	if not EconomyManager.spend_gold(player_id, card.cost):
		return false
	if not _apply_effect(processor, card):
		# Operación atómica: si el efecto falla, se devuelve el oro.
		EconomyManager.add_gold(player_id, card.cost)
		return false
	processor.get_draft().consume_card(player_id, offer_index)
	return true


func _apply_effect(processor: CommandProcessor, card: CardData) -> bool:
	match card.card_type:
		CardData.CardType.STRUCTURE:
			return processor.get_grid(player_id).build(slot_index, card.structure, card.cost) != null
		CardData.CardType.DIRECT_UNIT:
			var spawned: Array[UnitBase] = processor.get_lane().spawn_group_at(card.unit, player_id, card.unit_count, deploy_position)
			return spawned.size() == card.unit_count
	return false
