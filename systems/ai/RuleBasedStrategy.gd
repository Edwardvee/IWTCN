class_name RuleBasedStrategy
extends AIStrategy
## IA basada en reglas. En cada decisión:
##   1. Si no hay hueco para construir, compra el plot más barato; y si le
##      ofrecen una torre que quiere pero no tiene fila delantera, compra el
##      plot delantero más barato (las torres solo alcanzan el carril desde ahí).
##   2. Puntúa cada carta de la oferta según la situación (economía, ejército,
##      amenaza) y juega la mejor que pueda pagar si supera PLAY_THRESHOLD.
##   3. Si la oferta es mala y le sobra oro, hace reroll.
##   4. Si no, espera (ahorra).
## Las decisiones dependen solo de información pública y del stream de IA.
##
## Los pesos de la puntuación son campos: RuleBasedStrategy.create(perfil)
## devuelve variantes con estilos de juego distintos (economía, rush, torres…).
## Sirven de rivales variados en el modo espectador y de sparring del simulador
## de equilibrio (tools/BalanceSim.gd).

const PLAY_THRESHOLD: int = 20
## Oro que conserva tras un reroll para poder comprar después.
const REROLL_RESERVE: int = 60
## Variación aleatoria (determinista) añadida a las puntuaciones.
const SCORE_JITTER: int = 4
## Oro a partir del cual la IA gasta en tropas sin estar amenazada.
const SURPLUS_GOLD: int = 150
## Interés mínimo por las torres para comprar un plot delantero solo por ellas.
const TOWER_PLOT_MIN_INTEREST: int = 40

const PROFILE_BALANCED: StringName = &"balanced"
const PROFILE_ECONOMY: StringName = &"economy"
const PROFILE_RUSH: StringName = &"rush"
const PROFILE_TURTLE: StringName = &"turtle"
const PROFILE_BARRACKS: StringName = &"barracks"
const PROFILE_SPAM: StringName = &"spam"
## Solo para AIDifficulty (no salen en PROFILES: el espectador y el simulador
## enfrentan estilos, no niveles).
const PROFILE_EASY: StringName = &"easy"
const PROFILE_HARD: StringName = &"hard"
const PROFILES: Array[StringName] = [PROFILE_BALANCED, PROFILE_ECONOMY, PROFILE_RUSH, PROFILE_TURTLE, PROFILE_BARRACKS, PROFILE_SPAM]

var profile_name: StringName = PROFILE_BALANCED
## Granjas que quiere tener antes que nada / máximo de granjas que construye.
var farm_priority_count: int = 2
var farm_max_count: int = 4
## Puntuación de la 1.ª barraca; baja 10 por cada una que ya tiene.
var spawner_score: int = 85
## Iglesias: puntuación con >= 2 cuarteles.
var healer_score: int = 50
var tower_threat_score: int = 75
var tower_idle_score: int = 25
## Cartas de unidades sin amenaza (poco valor) y con oro de sobra.
var unit_idle_score: int = 10
var unit_surplus_score: int = 30
## --- Errores humanos (dificultad fácil) ---
## Probabilidad de no hacer nada en un turno de decisión.
var idle_chance: float = 0.0
## Probabilidad de comprar una carta asequible al azar en vez de la mejor.
var random_pick_chance: float = 0.0
var score_jitter: int = SCORE_JITTER
var play_threshold: int = PLAY_THRESHOLD
var allow_reroll: bool = true
var buff_army_score: int = 40
var tower_buff_score: int = 35
var buff_production_score: int = 45


static func create(profile: StringName) -> RuleBasedStrategy:
	var strategy: RuleBasedStrategy = RuleBasedStrategy.new()
	strategy.profile_name = profile
	match profile:
		PROFILE_ECONOMY:
			strategy.farm_priority_count = 3
			strategy.farm_max_count = 5
			strategy.spawner_score = 70
			strategy.tower_idle_score = 20
		PROFILE_RUSH:
			strategy.farm_priority_count = 1
			strategy.farm_max_count = 1
			strategy.spawner_score = 98
			strategy.unit_idle_score = 38
			strategy.unit_surplus_score = 60
			strategy.tower_idle_score = 5
			strategy.tower_threat_score = 45
		PROFILE_TURTLE:
			strategy.farm_priority_count = 2
			strategy.farm_max_count = 3
			strategy.spawner_score = 55
			strategy.tower_threat_score = 92
			strategy.tower_idle_score = 62
			strategy.tower_buff_score = 60
		PROFILE_BARRACKS:
			strategy.farm_priority_count = 1
			strategy.farm_max_count = 2
			strategy.spawner_score = 100
			strategy.buff_production_score = 70
			strategy.tower_idle_score = 10
		PROFILE_SPAM:
			strategy.farm_priority_count = 1
			strategy.farm_max_count = 2
			strategy.spawner_score = 30
			strategy.unit_idle_score = 60
			strategy.unit_surplus_score = 80
			strategy.tower_idle_score = 5
		PROFILE_EASY:
			# Pasiva y descuidada: economía lenta, poco ejército, muchos fallos.
			strategy.farm_priority_count = 1
			strategy.farm_max_count = 2
			strategy.spawner_score = 55
			strategy.unit_idle_score = 8
			strategy.tower_idle_score = 15
			strategy.idle_chance = 0.5
			strategy.random_pick_chance = 0.35
			strategy.score_jitter = 16
			strategy.play_threshold = 35
			strategy.allow_reroll = false
		PROFILE_HARD:
			# Presión temprana constante (cuarteles y tropas) con una sola granja,
			# torres solo bajo amenaza y mejoras cuando hay ejército.
			strategy.farm_priority_count = 1
			strategy.farm_max_count = 2
			strategy.spawner_score = 99
			strategy.healer_score = 60
			strategy.unit_idle_score = 40
			strategy.unit_surplus_score = 70
			strategy.tower_threat_score = 80
			strategy.tower_idle_score = 5
			strategy.buff_army_score = 55
			strategy.buff_production_score = 60
			strategy.tower_buff_score = 45
			strategy.score_jitter = 2
	return strategy


func choose_command(ai: AIController) -> GameCommand:
	var gold: int = ai.get_gold()
	var unlock: GameCommand = _maybe_unlock_plot(ai, gold)
	if unlock != null:
		return unlock
	var offer: Array[CardData] = ai.get_offer()
	unlock = _maybe_unlock_tower_plot(ai, gold, offer)
	if unlock != null:
		return unlock
	var best_index: int = -1
	var best_score: int = 0
	var top_score: int = 0
	var rng: RandomNumberGenerator = ai.get_rng()
	# Solo se consume azar de los "errores" si el nivel los tiene: así el nivel
	# normal sigue jugando exactamente igual que antes.
	if idle_chance > 0.0 and rng.randf() < idle_chance:
		return null
	var affordable: Array[int] = []
	for index: int in offer.size():
		var card: CardData = offer[index]
		var score: int = score_card(ai, card)
		if score <= 0:
			continue
		score += rng.randi_range(0, score_jitter)
		top_score = maxi(top_score, score)
		if EconomyManager.get_card_cost(ai.player_id, card) <= gold:
			affordable.append(index)
			if score > best_score:
				best_score = score
				best_index = index
	if random_pick_chance > 0.0 and not affordable.is_empty() and rng.randf() < random_pick_chance:
		var random_index: int = affordable[rng.randi_range(0, affordable.size() - 1)]
		return _make_play(ai, random_index, offer[random_index])
	if best_index >= 0 and best_score >= play_threshold:
		return _make_play(ai, best_index, offer[best_index])
	if allow_reroll and top_score < play_threshold and gold >= ai.get_reroll_cost() + REROLL_RESERVE:
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
			# Sin hueco bajo el tope de tropas la carta sería rechazada.
			if army + card.get_unit_count_for(ai.player_id) > ai.get_unit_cap():
				return 0
			# Defensa urgente: por encima de cualquier construcción.
			if threat > army:
				return 110
			# Sin amenaza, prioriza invertir en estructuras salvo que sobre oro.
			if card.unit.max_hp > 600.0:
				return maxi(50, unit_idle_score)
			return unit_surplus_score if ai.get_gold() >= SURPLUS_GOLD else unit_idle_score
		CardData.CardType.GLOBAL_BUFF:
			if card.buff.stat == BuffData.Stat.TOWER_FIRE_RATE:
				return tower_buff_score if ai.count_structures(&"tower") >= 1 else 0
			if card.buff.stat == BuffData.Stat.UNIT_CAP:
				# Solo sirve si el ejército ya roza el tope.
				return buff_army_score if army >= ai.get_unit_cap() - 3 else 0
			if card.buff.stat == BuffData.Stat.PRODUCTION_INTERVAL:
				return buff_production_score if barracks >= 2 else 5
			return buff_army_score if army >= 4 else 5
	return 0


func _score_structure(ai: AIController, structure: StructureData, threat: int, barracks: int) -> int:
	var is_tower: bool = structure.kind == StructureData.Kind.TOWER
	if ai.find_build_slot(is_tower) < 0:
		return 0
	var owned: int = ai.count_structures(structure.id)
	match structure.kind:
		StructureData.Kind.FARM:
			if owned < farm_priority_count:
				return 100
			# Con el ejército cerca del tope, otra granja es lo que lo amplía.
			if owned < structure.max_level and ai.get_army_size() >= ai.get_unit_cap() - 2:
				return 100
			return 55 if owned < farm_max_count else 15
		StructureData.Kind.TOWER:
			return tower_threat_score if threat > 0 else tower_idle_score
		StructureData.Kind.SPAWNER:
			if structure.spawn_unit != null and structure.spawn_unit.is_healer():
				return healer_score if barracks >= 2 and owned < 3 else 10
			return spawner_score - owned * 10 if owned < 2 else 45
	return 0


func _maybe_unlock_plot(ai: AIController, gold: int) -> GameCommand:
	if ai.find_build_slot(false) >= 0:
		return null
	var plot_index: int = ai.find_cheapest_locked_plot(false)
	if plot_index < 0 or gold < ai.get_plot_cost(plot_index):
		return null
	return UnlockPlotCommand.new(ai.player_id, plot_index, GameCommand.Source.AI)


## Hay una torre en la oferta que le interesa, pero no queda hueco en la fila
## delantera: desbloquea el plot delantero más barato si le sobra oro para la
## torre después.
func _maybe_unlock_tower_plot(ai: AIController, gold: int, offer: Array[CardData]) -> GameCommand:
	if ai.find_build_slot(true) >= 0:
		return null
	var wanted_tower: CardData = null
	for card: CardData in offer:
		if card.card_type == CardData.CardType.STRUCTURE and card.structure.kind == StructureData.Kind.TOWER:
			wanted_tower = card
	if wanted_tower == null:
		return null
	# Defenderse con tropas tiene prioridad sobre preparar una torre.
	if ai.get_threat() > ai.get_army_size():
		return null
	var interest: int = tower_threat_score if ai.get_threat() > 0 else tower_idle_score
	if interest < TOWER_PLOT_MIN_INTEREST:
		return null
	var plot_index: int = ai.find_cheapest_locked_plot(true)
	if plot_index < 0:
		return null
	if gold < ai.get_plot_cost(plot_index) + EconomyManager.get_card_cost(ai.player_id, wanted_tower):
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
