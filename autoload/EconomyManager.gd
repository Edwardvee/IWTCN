extends Node
## Única vía para leer y modificar el oro de los jugadores.
##
## Operaciones transaccionales: nunca deja el oro en negativo, rechaza
## cantidades negativas, jugadores inválidos, partidas no activas y
## llamadas sin autoridad (un cliente online no puede tocar el oro).
## Los ingresos periódicos se añaden en la Fase 2.


func get_gold(player_id: int) -> int:
	var player_state: PlayerState = GameManager.get_player_state(player_id)
	if player_state == null:
		return 0
	return player_state.gold


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
