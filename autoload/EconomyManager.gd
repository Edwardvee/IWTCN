extends Node
## Única vía para leer y modificar el oro de los jugadores.
##
## Operaciones transaccionales: nunca deja el oro en negativo, rechaza
## cantidades negativas, jugadores inválidos, partidas no activas y
## llamadas sin autoridad (un cliente online no puede tocar el oro).
##
## Ingreso base: rules.base_income_amount cada rules.base_income_interval
## segundos para cada jugador. El temporizador vive en PlayerState para que
## forme parte del estado serializable de la partida.
##
## Se conecta a partida_iniciada en su _ready (antes que cualquier nodo de
## escena), así el oro inicial ya está puesto cuando reaccionan los demás.


func _ready() -> void:
	EventBus.partida_iniciada.connect(_on_partida_iniciada)


func _physics_process(delta: float) -> void:
	simulate_step(delta)


## Avanza la economía `delta` segundos. Lo llama _physics_process;
## los tests lo llaman directamente para simular tiempo sin esperar.
func simulate_step(delta: float) -> void:
	if delta <= 0.0 or not GameManager.is_authority() or not GameManager.is_match_running():
		return
	var rules: GameRules = GameManager.get_rules()
	if rules == null or rules.base_income_interval <= 0.0:
		return
	for player_state: PlayerState in GameManager.match_state.players:
		player_state.base_income_timer += delta
		while player_state.base_income_timer >= rules.base_income_interval:
			player_state.base_income_timer -= rules.base_income_interval
			add_gold(player_state.player_id, rules.base_income_amount)


func get_gold(player_id: int) -> int:
	var player_state: PlayerState = GameManager.get_player_state(player_id)
	if player_state == null:
		return 0
	return player_state.gold


## Precio real de una carta para un jugador. Las estructuras suben de precio
## según las copias que ya tiene construidas; el resto cuesta card.cost.
func get_card_cost(player_id: int, card: CardData) -> int:
	if card == null:
		return 0
	if card.card_type != CardData.CardType.STRUCTURE or card.structure == null:
		return card.cost
	var rules: GameRules = GameManager.get_rules()
	var player_state: PlayerState = GameManager.get_player_state(player_id)
	if rules == null or player_state == null:
		return card.cost
	return rules.get_scaled_structure_cost(card.cost, player_state.grid.count_structures(card.structure.id))


func has_gold(player_id: int, amount: int) -> bool:
	if amount < 0:
		return false
	return get_gold(player_id) >= amount


func add_gold(player_id: int, amount: int) -> bool:
	if not _can_mutate(player_id, amount):
		return false
	var player_state: PlayerState = GameManager.get_player_state(player_id)
	player_state.gold += amount
	EventBus.oro_actualizado.emit(player_id, player_state.gold)
	return true


func spend_gold(player_id: int, amount: int) -> bool:
	if not _can_mutate(player_id, amount):
		return false
	var player_state: PlayerState = GameManager.get_player_state(player_id)
	if player_state.gold < amount:
		return false
	player_state.gold -= amount
	EventBus.oro_actualizado.emit(player_id, player_state.gold)
	return true


func _can_mutate(player_id: int, amount: int) -> bool:
	if amount < 0:
		push_warning("EconomyManager: cantidad negativa rechazada (%d)" % amount)
		return false
	if not GameManager.is_authority():
		return false
	if not GameManager.is_match_running():
		return false
	return GameManager.get_player_state(player_id) != null


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	if not GameManager.is_authority() or GameManager.match_state == null:
		return
	var rules: GameRules = GameManager.get_rules()
	var starting_gold: int = maxi(0, rules.starting_gold) if rules != null else 0
	for player_state: PlayerState in GameManager.match_state.players:
		player_state.gold = starting_gold
		player_state.base_income_timer = 0.0
		EventBus.oro_actualizado.emit(player_state.player_id, player_state.gold)
