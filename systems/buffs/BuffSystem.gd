class_name BuffSystem
extends RefCounted
## Buffs globales por jugador. Único punto que modifica PlayerState.buffs.
## Los buffs se acumulan (comprar dos veces el mismo suma dos veces).
## Añadir un buff nuevo = crear un BuffData .tres; solo un Stat nuevo exige código.


static func apply_buff(player_id: int, buff: BuffData) -> bool:
	var player_state: PlayerState = GameManager.get_player_state(player_id)
	if player_state == null or buff == null:
		return false
	player_state.buffs.append(buff.id)
	EventBus.buff_aplicado.emit(player_id, buff)
	return true


static func get_buffs(player_id: int) -> Array[BuffData]:
	var result: Array[BuffData] = []
	var player_state: PlayerState = GameManager.get_player_state(player_id)
	if player_state == null or GameManager.database == null:
		return result
	for buff_id: StringName in player_state.buffs:
		var buff: BuffData = GameManager.database.get_buff(buff_id)
		if buff != null:
			result.append(buff)
	return result


## Multiplicador de cadencia de las torres del jugador: 1.0 sin mejoras,
## 1.1 con una, 1.2 con dos… El cooldown de la torre se divide entre esto.
static func get_tower_fire_rate_multiplier(player_id: int) -> float:
	var bonus: float = 0.0
	for buff: BuffData in get_buffs(player_id):
		if buff.stat == BuffData.Stat.TOWER_FIRE_RATE:
			bonus += buff.value
	return 1.0 + bonus


## Intervalo de producción de unidades con los buffs PRODUCTION_INTERVAL
## aplicados, nunca por debajo de rules.min_production_interval.
static func get_production_interval(player_id: int, base_interval: float) -> float:
	var percent: float = 0.0
	var flat: float = 0.0
	for buff: BuffData in get_buffs(player_id):
		if buff.stat != BuffData.Stat.PRODUCTION_INTERVAL:
			continue
		if buff.operation == BuffData.Operation.PERCENT:
			percent += buff.value
		else:
			flat += buff.value
	var rules: GameRules = GameManager.get_rules()
	var minimum: float = rules.min_production_interval if rules != null else 1.0
	return maxf(minimum, base_interval * (1.0 + percent) + flat)
