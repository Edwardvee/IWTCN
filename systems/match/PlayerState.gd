class_name PlayerState
extends RefCounted
## Estado lógico de un jugador dentro de una partida.
##
## REGLA: solo EconomyManager escribe `gold` y `base_income_timer`;
## solo GridManager modifica `grid`; solo LaneManager modifica `castle_hp`;
## solo DraftManager modifica `shop`. El resto lo lee.

var player_id: int = MatchTypes.NO_PLAYER
var gold: int = 0
## Segundos acumulados hacia el próximo ingreso base.
var base_income_timer: float = 0.0
var grid: GridState
var castle_max_hp: float = 1.0
var castle_hp: float = 1.0
var shop: ShopState
## Ids de los buffs globales comprados (se acumulan). Solo BuffSystem escribe.
var buffs: Array[StringName] = []
## Multiplicador de los ingresos (base y granjas). 1.0 para jugadores; la
## dificultad de la IA lo cambia (ventaja o desventaja declarada). Solo lo
## escribe EconomyManager.set_income_multiplier; no viaja en los snapshots.
var income_multiplier: float = 1.0
## Fracción de oro de ingresos aún no entregada (evita perder decimales).
var income_remainder: float = 0.0


func _init(p_player_id: int, rules: GameRules) -> void:
	player_id = p_player_id
	var initial_plots: PackedInt32Array = rules.initial_unlocked_plots if rules != null else PackedInt32Array()
	grid = GridState.new(initial_plots)
	castle_max_hp = rules.castle_max_hp if rules != null else 1.0
	castle_hp = castle_max_hp
	shop = ShopState.new(rules.reroll_base_cost if rules != null else 0)


func is_castle_alive() -> bool:
	return castle_hp > 0.0


func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"gold": gold,
		"base_income_timer": base_income_timer,
		"castle_hp": castle_hp,
		"castle_max_hp": castle_max_hp,
		"grid": grid.to_dict(),
		"shop": shop.to_dict(),
		"buffs": buffs.duplicate(),
	}
