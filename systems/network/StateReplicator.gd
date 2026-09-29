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

## Partes del estado de un jugador que rara vez cambian y pueden omitirse.
const PERSISTENT_KEYS: PackedStringArray = ["grid", "shop", "buffs"]

var _grid_signatures: Dictionary[int, String] = {}


func setup(p_lane: LaneManager, p_grids: Array[GridManager]) -> void:
	lane = p_lane
	for grid: GridManager in p_grids:
		grids[grid.player_id] = grid


## Olvida lo aplicado antes (reinicio de una repetición).
func reset() -> void:
	_grid_signatures.clear()


## Snapshot completo. Sin el estado del azar ni los temporizadores internos
## (ingreso base, bajada del reroll): el cliente no los usa y cambian a cada tick.
func build_snapshot() -> Dictionary:
	var match_dict: Dictionary = GameManager.match_state.to_dict() if GameManager.match_state != null else {}
	match_dict.erase("random")
	for player_variant: Variant in match_dict.get("players", []):
		var player_dict: Dictionary = player_variant
		player_dict.erase("base_income_timer")
		(player_dict.get("shop", {}) as Dictionary).erase("reroll_decay_timer")
	return {
		"match": match_dict,
		"lane": lane.to_snapshot() if lane != null else {},
	}


## Snapshot que omite la cuadrícula, la tienda y las mejoras de un jugador si no
## han cambiado desde el último construido con el mismo `cache` (un diccionario
## que guarda quien lo pide, uno por destino). Con `cache` vacío sale completo:
## así un espectador o invitado que entra a mitad recibe todo. Quien lo aplica
## (apply_snapshot) conserva lo que no llega.
func build_delta_snapshot(cache: Dictionary) -> Dictionary:
	var snapshot: Dictionary = build_snapshot()
	for player_variant: Variant in (snapshot["match"] as Dictionary).get("players", []):
		var player_dict: Dictionary = player_variant
		var player_id: int = int(player_dict["player_id"])
		for key: String in PERSISTENT_KEYS:
			var cache_key: String = "%d/%s" % [player_id, key]
			var signature: int = hash(player_dict[key])
			if cache.get(cache_key, 0) == signature:
				player_dict.erase(key)
			else:
				cache[cache_key] = signature
	return snapshot


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

	# Los snapshots incrementales omiten lo que no cambió: solo se aplica lo que llega.
	if data.has("shop"):
		_apply_shop(player_id, player_state, data["shop"])
	if data.has("buffs"):
		_apply_buffs(player_id, player_state, data["buffs"])
	if not data.has("grid"):
		return
	var grid_dict: Dictionary = data["grid"]
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
