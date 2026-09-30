class_name ShopState
extends RefCounted
## Estado lógico de la tienda de un jugador. Solo DraftManager lo modifica.

## Ids de las cartas ofrecidas, por posición (0..shop_offer_size-1).
var offer: Array[StringName] = []
var reroll_cost: int = 0
## Segundos acumulados hacia la próxima rebaja del coste de reroll.
var reroll_decay_timer: float = 0.0
var reroll_count: int = 0
## Huecos de la tienda bloqueados por un sabotaje: hueco → match_time en que se desbloquean.
## El bloqueo es del hueco, no de la carta: sobrevive a los rerolls.
var blocked_until: Array[float] = []


func _init(base_reroll_cost: int) -> void:
	reroll_cost = base_reroll_cost


func is_blocked(offer_index: int, now: float) -> bool:
	return offer_index >= 0 and offer_index < blocked_until.size() and blocked_until[offer_index] > now


func block(offer_index: int, until: float) -> void:
	while blocked_until.size() <= offer_index:
		blocked_until.append(0.0)
	blocked_until[offer_index] = until


func to_dict() -> Dictionary:
	return {
		"offer": offer.duplicate(),
		"reroll_cost": reroll_cost,
		"reroll_decay_timer": reroll_decay_timer,
		"reroll_count": reroll_count,
		"blocked": blocked_until.duplicate(),
	}
