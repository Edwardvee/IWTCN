class_name StateReplicator
extends Node
## Snapshot del estado autoritativo (servidor) y su aplicación en clientes.
##
## Servidor: build_snapshot() = MatchState + carril (unidades/proyectiles).
## Cliente: apply_snapshot() copia ese estado y emite los mismos eventos del
## EventBus que en local, así la UI no distingue entre local y online.
## Única excepción a "solo X escribe Y": en un cliente (sin autoridad) este
## nodo refleja el estado del servidor en PlayerState/GridState.
## Un snapshot completo también sirve de reconexión: reconstruye todo.

var lane: LaneManager = null
var grids: Dictionary[int, GridManager] = {}

var _grid_signatures: Dictionary[int, String] = {}


func setup(p_lane: LaneManager, p_grids: Array[GridManager]) -> void:
	lane = p_lane
	for grid: GridManager in p_grids:
		grids[grid.player_id] = grid


## Olvida lo aplicado antes (reinicio de una repetición).
func reset() -> void:
	_grid_signatures.clear()


func build_snapshot() -> Dictionary:
	return {
		"match": GameManager.match_state.to_dict() if GameManager.match_state != null else {},
		"lane": lane.to_dict() if lane != null else {},
	}


func apply_snapshot(snapshot: Dictionary) -> void:
	if GameManager.is_authority() or GameManager.match_state == null:
		return
	var match_dict: Dictionary = snapshot.get("match", {})
	GameManager.match_state.match_time = float(match_dict.get("match_time", GameManager.match_state.match_time))
	for player_variant: Variant in match_dict.get("players", []):
		_apply_player(player_variant as Dictionary)
	if lane != null:
		lane.apply_snapshot(snapshot.get("lane", {}))


func _apply_player(data: Dictionary) -> void:
	var player_id: int = int(data.get("player_id", MatchTypes.NO_PLAYER))
	var player_state: PlayerState = GameManager.get_player_state(player_id)
	if player_state == null:
		return
	var gold: int = int(data.get("gold", player_state.gold))
	if gold != player_state.gold:
		player_state.gold = gold
		EventBus.oro_actualizado.emit(player_id, gold)

	var castle_hp: float = float(data.get("castle_hp", player_state.castle_hp))
	var castle_max_hp: float = float(data.get("castle_max_hp", player_state.castle_max_hp))
	if not is_equal_approx(castle_hp, player_state.castle_hp) or not is_equal_approx(castle_max_hp, player_state.castle_max_hp):
		player_state.castle_hp = castle_hp
		player_state.castle_max_hp = castle_max_hp
		EventBus.castillo_danado.emit(player_id, castle_hp, castle_max_hp)

	_apply_shop(player_id, player_state, data.get("shop", {}))
	_apply_buffs(player_id, player_state, data.get("buffs", []))

	var grid_dict: Dictionary = data.get("grid", {})
	var signature: String = str(grid_dict)
	if signature != _grid_signatures.get(player_id, ""):
		_grid_signatures[player_id] = signature
		player_state.grid.apply_dict(grid_dict)
		if grids.has(player_id):
			grids[player_id].resync_from_state()


func _apply_shop(player_id: int, player_state: PlayerState, shop_dict: Dictionary) -> void:
	var offer: Array[StringName] = []
	for card_variant: Variant in shop_dict.get("offer", []):
		offer.append(StringName(str(card_variant)))
	if offer != player_state.shop.offer:
		player_state.shop.offer = offer
		var cards: Array[CardData] = []
		for card_id: StringName in offer:
			var card: CardData = GameManager.database.get_card(card_id)
			if card != null:
				cards.append(card)
		EventBus.draft_ofrecido.emit(player_id, cards)
	var reroll_cost: int = int(shop_dict.get("reroll_cost", player_state.shop.reroll_cost))
	if reroll_cost != player_state.shop.reroll_cost:
		player_state.shop.reroll_cost = reroll_cost
		EventBus.coste_reroll_actualizado.emit(player_id, reroll_cost)


func _apply_buffs(player_id: int, player_state: PlayerState, buff_list: Array) -> void:
	for index: int in range(player_state.buffs.size(), buff_list.size()):
		var buff_id: StringName = StringName(str(buff_list[index]))
		player_state.buffs.append(buff_id)
		var buff: BuffData = GameManager.database.get_buff(buff_id)
		if buff != null:
			EventBus.buff_aplicado.emit(player_id, buff)
