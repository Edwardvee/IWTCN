class_name RuleBasedStrategy
extends AIStrategy
## IA basada en reglas. En cada decisión:
##   1. Si no hay hueco para construir, compra el plot más barato.
##   2. Puntúa cada carta de la oferta según la situación (economía, ejército,
##      amenaza) y juega la mejor que pueda pagar si supera PLAY_THRESHOLD.
##   3. Si la oferta es mala y le sobra oro, hace reroll.
##   4. Si no, espera (ahorra).
## Las decisiones dependen solo de información pública y del stream de IA.

const PLAY_THRESHOLD: int = 20
## Oro que conserva tras un reroll para poder comprar después.
const REROLL_RESERVE: int = 60
## Variación aleatoria (determinista) añadida a las puntuaciones.
const SCORE_JITTER: int = 4
## Oro a partir del cual la IA gasta en tropas sin estar amenazada.
const SURPLUS_GOLD: int = 150


func choose_command(ai: AIController) -> GameCommand:
	var gold: int = ai.get_gold()
	var unlock: GameCommand = _maybe_unlock_plot(ai, gold)
	if unlock != null:
		return unlock
	var offer: Array[CardData] = ai.get_offer()
	var best_index: int = -1
	var best_score: int = 0
	var top_score: int = 0
	var rng: RandomNumberGenerator = ai.get_rng()
	for index: int in offer.size():
		var card: CardData = offer[index]
		var score: int = score_card(ai, card)
		if score <= 0:
			continue
		score += rng.randi_range(0, SCORE_JITTER)
		top_score = maxi(top_score, score)
		if EconomyManager.get_card_cost(ai.player_id, card) <= gold and score > best_score:
			best_score = score
			best_index = index
	if best_index >= 0 and best_score >= PLAY_THRESHOLD:
		return _make_play(ai, best_index, offer[best_index])
	if top_score < PLAY_THRESHOLD and gold >= ai.get_reroll_cost() + REROLL_RESERVE:
		return RerollShopCommand.new(ai.player_id, GameCommand.Source.AI)
	return null


## Puntuación de utilidad de una carta (0 = no jugarla).
func score_card(ai: AIController, card: CardData) -> int:
	var threat: int = ai.get_threat()
	var army: int = ai.get_army_size()
	var barracks: int = ai.count_structures_with_tag(&"barracks")
	match card.card_type:
		CardData.CardType.STRUCTURE:
			return _score_structure(ai, card.structure, threat, barracks)
		CardData.CardType.DIRECT_UNIT:
			# Defensa urgente: por encima de cualquier construcción.
			if threat > army:
				return 110
			# Sin amenaza, prioriza invertir en estructuras salvo que sobre oro.
			if card.unit.max_hp > 600.0:
				return 50
			return 30 if ai.get_gold() >= SURPLUS_GOLD else 10
		CardData.CardType.GLOBAL_BUFF:
			if card.buff.stat == BuffData.Stat.PRODUCTION_INTERVAL:
				return 45 if barracks >= 2 else 5
			return 40 if army >= 4 else 5
	return 0


func _score_structure(ai: AIController, structure: StructureData, threat: int, barracks: int) -> int:
	var is_tower: bool = structure.kind == StructureData.Kind.TOWER
	if ai.find_build_slot(is_tower) < 0:
		return 0
	var owned: int = ai.count_structures(structure.id)
	match structure.kind:
		StructureData.Kind.FARM:
			if owned < 2:
				return 100
			return 55 if owned < 4 else 15
		StructureData.Kind.TOWER:
			return 75 if threat > 0 else 25
		StructureData.Kind.SPAWNER:
			if structure.spawn_unit != null and structure.spawn_unit.is_healer():
				return 50 if barracks >= 2 and owned < 3 else 10
			return 85 - owned * 10 if owned < 2 else 45
	return 0


func _maybe_unlock_plot(ai: AIController, gold: int) -> GameCommand:
	if ai.find_build_slot(false) >= 0:
		return null
	var plot_index: int = ai.find_cheapest_locked_plot(false)
	if plot_index < 0 or gold < ai.get_plot_cost(plot_index):
		return null
	return UnlockPlotCommand.new(ai.player_id, plot_index, GameCommand.Source.AI)


func _make_play(ai: AIController, offer_index: int, card: CardData) -> GameCommand:
	var slot_index: int = -1
	var deploy: Vector2 = Vector2.ZERO
	match card.card_type:
		CardData.CardType.STRUCTURE:
			slot_index = ai.find_build_slot(card.structure.kind == StructureData.Kind.TOWER)
			if slot_index < 0:
				return null
		CardData.CardType.DIRECT_UNIT:
			deploy = ai.get_deploy_point()
	return PlayCardCommand.new(ai.player_id, offer_index, card.id, slot_index, deploy, GameCommand.Source.AI)
