class_name DraftManager
extends Node
## Tienda de cartas de cada jugador (sustituye al draft de 25 s).
##
## - Oferta de rules.shop_offer_size cartas DISTINTAS, elegidas al azar con
##   peso (shop_weight) usando el stream de tienda del jugador (MatchRandom).
## - Al comprar una carta la tienda se renueva entera, gratis.
## - Reroll manual: cuesta reroll_cost; cada uso lo sube reroll_cost_increment;
##   cada reroll_decay_interval segundos baja reroll_decay_amount hasta el base.
## - Una carta solo aparece si está disponible para ese jugador: tipo
##   habilitado, requisito de desbloqueo cumplido (Tank: 3 cuarteles) y, si es
##   una estructura, que no esté ya al máximo de nivel.
##
## Solo lo modifican los comandos (PlayCardCommand, RerollShopCommand) y su
## propio tick. La IA leerá la misma oferta que ve un jugador humano.

## Tipos de carta que pueden salir en la tienda (GLOBAL_BUFF se activa en la Fase 10).
@export var enabled_card_types: Array[CardData.CardType] = [CardData.CardType.STRUCTURE, CardData.CardType.DIRECT_UNIT]


func _ready() -> void:
	EventBus.partida_iniciada.connect(_on_partida_iniciada)


func _physics_process(delta: float) -> void:
	simulate_step(delta)


func simulate_step(delta: float) -> void:
	if delta <= 0.0 or not GameManager.is_authority() or not GameManager.is_match_running():
		return
	var rules: GameRules = GameManager.get_rules()
	if rules == null:
		return
	for player_state: PlayerState in GameManager.match_state.players:
		_decay_reroll_cost(player_state, rules, delta)


# --- Consultas -----------------------------------------------------------------

func get_offer(player_id: int) -> Array[CardData]:
	var cards: Array[CardData] = []
	var shop: ShopState = _get_shop(player_id)
	if shop == null or GameManager.database == null:
		return cards
	for card_id: StringName in shop.offer:
		var card: CardData = GameManager.database.get_card(card_id)
		if card != null:
			cards.append(card)
	return cards


func get_offer_card_id(player_id: int, offer_index: int) -> StringName:
	var shop: ShopState = _get_shop(player_id)
	if shop == null or offer_index < 0 or offer_index >= shop.offer.size():
		return &""
	return shop.offer[offer_index]


func get_reroll_cost(player_id: int) -> int:
	var shop: ShopState = _get_shop(player_id)
	return shop.reroll_cost if shop != null else 0


func is_card_available(player_id: int, card: CardData) -> bool:
	var player_state: PlayerState = GameManager.get_player_state(player_id)
	if player_state == null or card == null or not enabled_card_types.has(card.card_type):
		return false
	if card.has_unlock_requirement():
		var owned: int = player_state.grid.count_structures_with_tag(card.required_structure_tag, GameManager.database)
		if owned < card.required_structure_count:
			return false
	if card.card_type == CardData.CardType.STRUCTURE and card.structure != null:
		if player_state.grid.count_structures(card.structure.id) >= card.structure.max_level:
			return false
	return true


func get_available_cards(player_id: int) -> Array[CardData]:
	var available: Array[CardData] = []
	if GameManager.database == null:
		return available
	for card: CardData in GameManager.database.cards:
		if is_card_available(player_id, card):
			available.append(card)
	return available


# --- Mutaciones (comandos y tick) ------------------------------------------------

## Genera una oferta nueva con el stream de tienda del jugador.
func refresh_offer(player_id: int) -> void:
	var shop: ShopState = _get_shop(player_id)
	var rules: GameRules = GameManager.get_rules()
	if shop == null or rules == null:
		return
	var rng: RandomNumberGenerator = GameManager.match_state.random.get_stream(MatchRandom.STREAM_SHOP, player_id)
	var candidates: Array[CardData] = get_available_cards(player_id)
	var offer: Array[StringName] = []
	while offer.size() < rules.shop_offer_size and not candidates.is_empty():
		var picked: int = _pick_weighted_index(candidates, rng)
		offer.append(candidates[picked].id)
		candidates.remove_at(picked)
	shop.offer = offer
	EventBus.draft_ofrecido.emit(player_id, get_offer(player_id))


## Reroll ya pagado por RerollShopCommand.
func apply_reroll(player_id: int) -> void:
	var shop: ShopState = _get_shop(player_id)
	var rules: GameRules = GameManager.get_rules()
	if shop == null or rules == null:
		return
	shop.reroll_count += 1
	shop.reroll_cost += rules.reroll_cost_increment
	EventBus.coste_reroll_actualizado.emit(player_id, shop.reroll_cost)
	refresh_offer(player_id)


## La carta de `offer_index` se ha jugado (ya pagada y aplicada): se anuncia
## y la tienda se renueva entera.
func consume_card(player_id: int, offer_index: int) -> void:
	var card: CardData = GameManager.database.get_card(get_offer_card_id(player_id, offer_index))
	if card != null:
		EventBus.carta_elegida.emit(player_id, card)
	refresh_offer(player_id)


## Solo tests y panel debug: fija la oferta sin azar.
func force_offer(player_id: int, card_ids: Array[StringName]) -> void:
	var shop: ShopState = _get_shop(player_id)
	if shop == null:
		return
	shop.offer = card_ids.duplicate()
	EventBus.draft_ofrecido.emit(player_id, get_offer(player_id))


# --- Interno ---------------------------------------------------------------------

func _get_shop(player_id: int) -> ShopState:
	var player_state: PlayerState = GameManager.get_player_state(player_id)
	return player_state.shop if player_state != null else null


## Índice elegido con probabilidad proporcional a shop_weight. El orden de
## candidatos es el de la base de datos, así que el resultado es determinista.
func _pick_weighted_index(candidates: Array[CardData], rng: RandomNumberGenerator) -> int:
	var total_weight: int = 0
	for card: CardData in candidates:
		total_weight += maxi(1, card.shop_weight)
	var roll: int = rng.randi_range(0, total_weight - 1)
	for index: int in candidates.size():
		roll -= maxi(1, candidates[index].shop_weight)
		if roll < 0:
			return index
	return candidates.size() - 1


func _decay_reroll_cost(player_state: PlayerState, rules: GameRules, delta: float) -> void:
	var shop: ShopState = player_state.shop
	if shop.reroll_cost <= rules.reroll_base_cost:
		shop.reroll_decay_timer = 0.0
		return
	shop.reroll_decay_timer += delta
	var changed: bool = false
	while shop.reroll_decay_timer >= rules.reroll_decay_interval and shop.reroll_cost > rules.reroll_base_cost:
		shop.reroll_decay_timer -= rules.reroll_decay_interval
		shop.reroll_cost = maxi(rules.reroll_base_cost, shop.reroll_cost - rules.reroll_decay_amount)
		changed = true
	if shop.reroll_cost <= rules.reroll_base_cost:
		shop.reroll_decay_timer = 0.0
	if changed:
		EventBus.coste_reroll_actualizado.emit(player_state.player_id, shop.reroll_cost)


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	if not GameManager.is_authority() or GameManager.match_state == null:
		return
	for player_state: PlayerState in GameManager.match_state.players:
		EventBus.coste_reroll_actualizado.emit(player_state.player_id, player_state.shop.reroll_cost)
		refresh_offer(player_state.player_id)
